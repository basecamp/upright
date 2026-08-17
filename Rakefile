require "bundler/setup"

APP_RAKEFILE = File.expand_path("test/dummy/Rakefile", __dir__)
load "rails/tasks/engine.rake"

Dir.glob("lib/tasks/**/*.rake").each { |r| load r }

# Releases are cut by the tag-triggered .github/workflows/release.yml, so
# bundler/gem_tasks (whose `release` task builds, tags, and pushes the gem
# from a laptop) is deliberately not loaded. See RELEASING.md.

VERSION_FILE = "lib/upright/version.rb"

def upright_version
  require_relative "lib/upright/version"
  Upright::VERSION
end

def clean_tree?
  `git status --porcelain`.empty?
end

desc "Rewrite version.rb to VERSION (exact semver, strictly greater) and refresh Gemfile.lock; commits nothing"
task :bump, [ :version ] do |_t, args|
  version = args[:version].to_s
  # Exact SemVer: numeric identifiers may not have leading zeros.
  unless version.match?(/\A(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\z/)
    abort "bump: version must be exact semver X.Y.Z (got #{version.inspect})"
  end
  abort "bump: working tree must be clean" unless clean_tree?

  current = upright_version
  unless Gem::Version.new(version) > Gem::Version.new(current)
    abort "bump: #{version} must be strictly greater than the current #{current}"
  end

  contents = File.read(VERSION_FILE)
  rewritten = contents.sub(%(VERSION = "#{current}"), %(VERSION = "#{version}"))
  abort "bump: could not find VERSION = \"#{current}\" in #{VERSION_FILE}" if rewritten == contents
  File.write(VERSION_FILE, rewritten)

  sh "bundle install --quiet" # refresh Gemfile.lock's upright version
  puts "Bumped #{current} -> #{version}. Review, commit (with a CHANGELOG entry), and PR; `rake tag` after merge cuts the release."
end

desc "Tag and push v<current version> to trigger the release workflow"
task :tag do
  version = upright_version
  tag = "v#{version}"

  abort "tag: working tree must be clean" unless clean_tree?

  branch = `git rev-parse --abbrev-ref HEAD`.strip
  abort "tag: must be on main (currently on #{branch})" unless branch == "main"

  sh "git fetch origin main --quiet"
  head = `git rev-parse HEAD`.strip
  origin = `git rev-parse origin/main`.strip
  abort "tag: HEAD (#{head[0, 12]}) != origin/main (#{origin[0, 12]}); reconcile first" unless head == origin

  abort "tag: #{tag} already exists locally" unless `git tag --list #{tag}`.strip.empty?
  abort "tag: #{tag} already exists on origin" unless `git ls-remote --tags origin refs/tags/#{tag}`.strip.empty?

  # Push main first so the release workflow's ancestry guard (tag commit must
  # be on origin/main) can never race the tag.
  sh "git push origin main"
  sh "git tag --annotate #{tag} --message 'upright #{tag}'"
  sh "git push origin #{tag}"
  puts "Pushed #{tag}. The release workflow takes it from here — approve the release-rubygems environment when prompted."
end
