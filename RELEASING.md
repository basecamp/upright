# Releasing upright

A release is a `vX.Y.Z` tag on `main`. Pushing the tag runs
`.github/workflows/release.yml`, which has one job in the `release-rubygems`
environment. After a reviewer approves it, the job:

1. Checks that the tag matches `Upright::VERSION` and that the tagged commit
   is on `origin/main`.
2. Runs `rubygems/release-gem`. That action obtains a short-lived credential
   from RubyGems trusted publishing, runs `rake release` (which builds the gem
   into `pkg/`, skips tagging because the tag exists, and pushes the gem with
   a sigstore attestation), and waits until rubygems.org serves the version.
3. Creates the GitHub Release for the tag with generated notes and the built
   gem attached.

The gemspec lists files with `git ls-files`, so nothing untracked or ignored
can enter the package. `test/packaging_test.rb` checks this in CI. RubyGems
builds reproducibly by default, so `gem build upright.gemspec` at the tag
produces the same bytes as the published gem.

## Cutting a release

1. On a branch, set the new version in `lib/upright/version.rb`, run
   `bundle install` to refresh `Gemfile.lock`, move the CHANGELOG's Unreleased
   notes under the new version, open a PR, and merge it.

   A `playwright-ruby-client` constraint change is not a routine bump.
   `Upright::PLAYWRIGHT_VERSION`, the gemspec constraint, `package.json`, the
   install generator's Dockerfile and `test/dummy/docker-compose.yml` change
   together.
2. On an up-to-date `main` checkout, run `rake tag`. It stops if the tree is
   dirty, the branch is not `main`, `HEAD` differs from `origin/main`, or the
   tag already exists. Otherwise it creates the annotated tag and pushes it.
3. Approve the `release-rubygems` environment when the workflow pauses.
4. When the run finishes, check the result:

   ```sh
   gem fetch upright -v X.Y.Z
   gh release download vX.Y.Z --pattern '*.gem' --output github-upright-X.Y.Z.gem
   sha256sum upright-X.Y.Z.gem github-upright-X.Y.Z.gem
   ```

   The two digests must be equal. The gem's page on rubygems.org shows the
   provenance from the attestation, naming this repository, the workflow and
   the tag.

Push one tag at a time. The workflow's concurrency group keeps one pending
run, so a second tag pushed while a run is in progress replaces the queued
one.

## Recovery

| State | What to do |
|---|---|
| The run failed before `gem push` | Fix on `main`, delete the tag, tag again. Deleting is allowed only because nothing was published. |
| The gem was pushed, then creating the GitHub Release failed | Do not re-run: `gem push` refuses an existing version. Create the release by hand: `gem fetch upright -v X.Y.Z` then `gh release create vX.Y.Z upright-X.Y.Z.gem --verify-tag --generate-notes`. |
| A published release is bad | Do not move or delete the tag. Publish a new patch version. Yank only for a security problem in the published gem. |

## One-time setup

Set `RELEASE_REVIEWER` to the GitHub login of the person who approves
releases.

1. **Default workflow token.** Make the default `GITHUB_TOKEN` read-only. The
   release job declares the permissions it needs.

   ```sh
   gh api -X PUT repos/basecamp/upright/actions/permissions/workflow \
     -f default_workflow_permissions=read
   ```

2. **Environment `release-rubygems`.** One required reviewer,
   `prevent_self_review: false` so the releaser can approve their own release,
   `can_admins_bypass: false`, and a deployment branch policy that allows only
   `v*` tags.

   ```sh
   reviewer_id=$(gh api "users/${RELEASE_REVIEWER}" --jq .id)
   gh api -X PUT repos/basecamp/upright/environments/release-rubygems \
     --input - <<JSON
   { "reviewers": [{ "type": "User", "id": ${reviewer_id} }],
     "prevent_self_review": false,
     "can_admins_bypass": false,
     "deployment_branch_policy": { "protected_branches": false, "custom_branch_policies": true } }
   JSON
   gh api -X POST repos/basecamp/upright/environments/release-rubygems/deployment-branch-policies \
     -f name='v*' -f type=tag
   ```

3. **Tag rulesets.** Two rulesets on `refs/tags/v*` with enforcement
   `active`: one restricts creation, with the releaser as the only bypass
   actor; the other blocks update and deletion with no bypass actors.

4. **RubyGems trusted publisher.** On rubygems.org, in the `upright` gem's
   trusted publishing settings, add a GitHub Actions publisher with repository
   `basecamp/upright`, workflow `release.yml` and environment
   `release-rubygems`. Then remove any long-lived API keys from the owner
   accounts and confirm every owner has MFA enabled, so the workflow is the
   only way to push.

5. **Pinned actions.** After this workflow is merged, enable "Require actions
   to be pinned to a full-length commit SHA" in the repository's Actions
   settings.
