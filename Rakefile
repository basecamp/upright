require "bundler/setup"

APP_RAKEFILE = File.expand_path("test/dummy/Rakefile", __dir__)
load "rails/tasks/engine.rake"

require "bundler/gem_tasks"

Dir.glob("lib/tasks/**/*.rake").each { |r| load r }

desc "Tag v<current version> and push it, which starts the Release workflow"
task :tag do
  require_relative "lib/upright/version"
  tag = "v#{Upright::VERSION}"

  abort "tag: the working tree has uncommitted changes" unless `git status --porcelain`.empty?

  branch = `git rev-parse --abbrev-ref HEAD`.strip
  abort "tag: run this on main (currently on #{branch})" unless branch == "main"

  sh "git fetch origin main --quiet"
  abort "tag: HEAD differs from origin/main; pull or push first" unless `git rev-parse HEAD`.strip == `git rev-parse origin/main`.strip
  abort "tag: #{tag} already exists locally" unless `git tag --list #{tag}`.strip.empty?
  abort "tag: #{tag} already exists on origin" unless `git ls-remote --tags origin refs/tags/#{tag}`.strip.empty?

  sh "git tag --annotate #{tag} --message 'upright #{tag}'"
  sh "git push origin #{tag}"
  puts "Pushed #{tag}. Approve the release-rubygems environment when the Release workflow pauses."
end
