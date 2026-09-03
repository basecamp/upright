# Contributing to Upright

Thank you for considering contributing to Upright! Here are some guidelines to help you get started.

## Reporting Issues

If you encounter a bug or have a feature request, please open an issue on the [GitHub Issues tracker](https://github.com/basecamp/upright/issues). Check existing issues first to avoid duplicates.

## Pull Requests

- Keep changes focused on a single concern
- Include tests for new functionality
- Ensure the test suite passes: `bin/rails test`
- Ensure linting passes: `bin/rubocop`
- Write clear commit messages

## Development Setup

```bash
git clone https://github.com/basecamp/upright.git
cd upright/test/dummy
bundle install
bin/services  # starts Prometheus, AlertManager, and Playwright via Docker
bin/dev       # starts the Rails dev server
```

Visit http://app.upright.localhost:3000 and sign in with `admin` / `upright`.

## Running Tests

```bash
bin/rails test
```

Playwright integration tests require Docker. Start the Playwright server with `bin/services` before running the full suite.

## Releasing

Releases are built and published by GitHub Actions from a tag on `main`, not
from a laptop. `RELEASING.md` describes the workflow, the version bump and tag
steps, verification, recovery, and the one-time repository setup.
