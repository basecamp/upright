# frozen_string_literal: true

require "rubygems/package"
require "tmpdir"

module Upright
  module Release
    # Verifies a freshly built .gem end to end: archive integrity, spec
    # identity, dependencies and contents exactly matching the repo's
    # gemspec, and a real install into an isolated GEM_HOME. Run on every
    # build, rehearsals included. Fails closed on the first problem.
    #
    # Runs from the repo root with the checkout present: the reference
    # gemspec and `git ls-files` are the source of truth the package is
    # compared against.
    class PackageVerification
      class Failure < StandardError; end

      GEMSPEC = "upright.gemspec"

      # Keep child processes honest: no bundler, ruby options, or load-path
      # additions leaking in from CI — RUBYLIB especially, which could let
      # the version probe resolve from the checkout instead of the
      # installed gem and wave a broken package through.
      CLEAN_ENV = {
        "RUBYOPT" => nil, "RUBYLIB" => nil, "RUBYGEMS_GEMDEPS" => nil,
        "BUNDLE_GEMFILE" => nil, "BUNDLE_PATH" => nil
      }.freeze

      # Live wiring: subprocesses run for real, the reference gemspec and the
      # git-tracked file list come from the checkout. Tests inject all three.
      def self.live(gem_file, name:, version:, out: $stdout)
        new(gem_file, name: name, version: version, out: out,
            runner: ->(env, *command) { Kernel.system(env, *command) },
            reference: -> { Gem::Specification.load(GEMSPEC) },
            tracked_files: -> { `git ls-files -z`.split("\0") })
      end

      # CLI entry point; returns a process exit status.
      def self.run(argv, out: $stdout, err: $stderr, verification_for: method(:live))
        gem_file, name, version = argv
        if argv.size != 3
          err.puts "usage: verify_package.rb GEM_FILE NAME VERSION"
          return 2
        end
        unless File.file?(gem_file)
          err.puts "no such file: #{gem_file}"
          return 2
        end

        verification_for.call(gem_file, name: name, version: version, out: out).verify!
        0
      rescue Failure => e
        err.puts "verify_package: #{e.message}"
        1
      end

      def initialize(gem_file, name:, version:, runner:, reference:, tracked_files:, out: $stdout)
        @gem_file = gem_file
        @name = name
        @version = version
        @runner = runner
        @reference = reference
        @tracked_files = tracked_files
        @out = out
      end

      def verify!
        package = check("archive integrity (Gem::Package#verify)") do
          Gem::Package.new(@gem_file).tap(&:verify)
        end
        spec = package.spec

        check("spec name is #{@name}") do
          raise "got #{spec.name.inspect}" unless spec.name == @name
        end

        check("spec version is #{@version}") do
          raise "got #{spec.version}" unless spec.version.to_s == @version
        end

        reference = check("reference gemspec loads") do
          @reference.call or raise "could not load the reference gemspec"
        end

        # Guards against build-environment contamination without freezing
        # the ~30-gem dependency list in a second place.
        check("dependencies exactly match the gemspec") do
          expected = dependency_list(reference)
          actual = dependency_list(spec)
          missing = expected - actual
          unexpected = actual - expected
          problems = []
          problems << "missing: #{missing.join(", ")}" unless missing.empty?
          problems << "unexpected: #{unexpected.join(", ")}" unless unexpected.empty?
          raise problems.join("; ") unless problems.empty?
        end

        contents = package.contents
        @out.puts "verify: archive contents:"
        contents.sort.each { |path| @out.puts "  #{path}" }

        # The gemspec's Dir globs are evaluated against the working tree, so
        # an untracked file dropped into app/ or lib/ during the build would
        # be packaged. Filtering the expectation through `git ls-files`
        # (the tag's tracked content) makes that contamination a failure
        # instead of a silently wider gem.
        check("packaged files exactly match the gemspec's git-tracked file list") do
          tracked = @tracked_files.call
          raise "git ls-files reported nothing; is this a checkout?" if tracked.empty?
          expected = (reference.files & tracked).select { |path| File.file?(path) }
          raise "gemspec file list resolved to nothing" if expected.empty?
          missing = expected.sort - contents.sort
          unexpected = contents.sort - expected.sort
          problems = []
          problems << "missing: #{missing.join(", ")}" unless missing.empty?
          problems << "unexpected: #{unexpected.join(", ")}" unless unexpected.empty?
          raise problems.join("; ") unless problems.empty?
        end

        check("installs cleanly into an isolated GEM_HOME") do
          Dir.mktmpdir("#{@name}-verify") do |gem_home|
            env = CLEAN_ENV.merge("GEM_HOME" => gem_home, "GEM_PATH" => gem_home)

            # --ignore-dependencies: the runtime dependencies are not in the
            # empty GEM_HOME, and fetching all of them here would verify
            # RubyGems' resolver rather than our package.
            unless @runner.call(env, "gem", "install", "--local", "--no-document", "--ignore-dependencies", @gem_file)
              raise "gem install failed"
            end

            # Probe the installed files directly (upright/version has no
            # dependencies); a full `require "upright"` would need Rails
            # and its whole dependency tree activated.
            installed_lib = File.join(gem_home, "gems", "#{@name}-#{@version}", "lib")
            probe = %(require "upright/version"; abort "version mismatch: \#{Upright::VERSION}" unless Upright::VERSION == ARGV[0])
            unless @runner.call(env, "ruby", "-I", installed_lib, "-e", probe, @version)
              raise "version probe failed"
            end
          end
        end

        @out.puts "verify: #{File.basename(@gem_file)} passed all checks"
        true
      end

      private
        def dependency_list(spec)
          spec.dependencies.map { |dep| "#{dep.name} (#{dep.type}, #{dep.requirement})" }.sort
        end

        def check(description)
          @out.print "verify: #{description}... "
          result = yield
          @out.puts "ok"
          result
        rescue StandardError => e
          @out.puts "FAIL"
          raise Failure, "#{description}: #{e.message}"
        end
    end
  end
end
