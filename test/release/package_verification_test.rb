# frozen_string_literal: true

require "test_helper"
require_relative "../../script/release/package_verification"

require "fileutils"
require "stringio"
require "tmpdir"

# Fixture tests for the build-job package verifier: every check is exercised
# with a real (tiny) gem built in a temp dir — valid, corrupted, misnamed,
# misversioned, dependency-drifted, contaminated, and incomplete variants.
# The install/probe subprocesses are scripted so failures are testable, and
# the reference gemspec + tracked-file list are injected the same way the
# live wiring supplies them from the checkout.
class PackageVerificationTest < ActiveSupport::TestCase
  Verification = Upright::Release::PackageVerification

  DEFAULT_FILES = {
    "lib/upright.rb"         => "# fixture\n",
    "lib/upright/version.rb" => "# fixture\n",
    "README.md"              => "readme\n",
    "LICENSE.md"             => "license\n"
  }.freeze

  setup do
    @dir = Dir.mktmpdir("package-verification-test")
    @out = StringIO.new
  end

  teardown do
    FileUtils.remove_entry(@dir)
  end

  test "a well formed gem passes every check and runs install plus version probe" do
    fixture = build_fixture
    commands = []
    runner = lambda { |env, *command|
      commands << command
      assert_equal env["GEM_HOME"], env["GEM_PATH"]
      assert_nil env["RUBYOPT"]
      assert_nil env["RUBYLIB"]
      assert_nil env["RUBYGEMS_GEMDEPS"]
      true
    }

    assert run_verify(fixture, runner: runner)
    assert_equal 2, commands.size
    assert_equal %w[ gem install --local --no-document --ignore-dependencies ], commands.first.first(5)
    assert_equal %w[ ruby -I ], commands.last.first(2)
    assert_match(/passed all checks/, @out.string)
  end

  test "a corrupted archive fails the integrity check" do
    fixture = build_fixture
    File.binwrite(fixture.gem_file, File.binread(fixture.gem_file).byteslice(0, 100))

    error = assert_raises(Verification::Failure) { run_verify(fixture) }
    assert_match(/archive integrity/, error.message)
  end

  test "a different gem name fails" do
    fixture = build_fixture(name: "imposter")
    error = assert_raises(Verification::Failure) { run_verify(fixture, name: "upright") }
    assert_match(/spec name/, error.message)
  end

  test "a different version fails" do
    fixture = build_fixture(version: "9.9.9")
    error = assert_raises(Verification::Failure) { run_verify(fixture, version: "0.1.0") }
    assert_match(/spec version/, error.message)
  end

  test "an unloadable reference gemspec fails" do
    fixture = build_fixture
    error = assert_raises(Verification::Failure) { run_verify(fixture, reference: -> { nil }) }
    assert_match(/reference gemspec loads/, error.message)
  end

  test "a dependency missing from the package fails" do
    fixture = build_fixture(reference_dependencies: %w[ rake ])
    error = assert_raises(Verification::Failure) { run_verify(fixture) }
    assert_match(/dependencies exactly match the gemspec: missing: rake/, error.message)
  end

  test "a dependency the gemspec does not declare fails" do
    fixture = build_fixture(dependencies: %w[ rake ], reference_dependencies: [])
    error = assert_raises(Verification::Failure) { run_verify(fixture) }
    assert_match(/dependencies exactly match the gemspec: unexpected: rake/, error.message)
  end

  test "a dependency with a drifted requirement fails" do
    fixture = build_fixture(dependencies: [ [ "rake", ">= 13" ] ], reference_dependencies: [ [ "rake", ">= 12" ] ])
    error = assert_raises(Verification::Failure) { run_verify(fixture) }
    assert_match(/dependencies exactly match the gemspec/, error.message)
  end

  test "a packaged file that is not git-tracked fails as contamination" do
    # The contaminant is on disk, so the gemspec's Dir globs (modeled by the
    # reference spec's file list) pick it up and it gets packaged — but git
    # doesn't track it. Exactly the build-environment contamination case.
    contaminated = DEFAULT_FILES.merge("lib/upright/payload.rb" => "!\n")
    fixture = build_fixture(files: contaminated, tracked: DEFAULT_FILES.keys)
    error = assert_raises(Verification::Failure) { run_verify(fixture) }
    assert_match(/git-tracked file list: unexpected: lib\/upright\/payload\.rb/, error.message)
  end

  test "a tracked gemspec file missing from the package fails" do
    fixture = build_fixture(packaged: DEFAULT_FILES.keys - %w[ LICENSE.md ])
    error = assert_raises(Verification::Failure) { run_verify(fixture) }
    assert_match(/git-tracked file list: missing: LICENSE\.md/, error.message)
  end

  test "an empty tracked-file list fails rather than passing vacuously" do
    fixture = build_fixture(tracked: [])
    error = assert_raises(Verification::Failure) { run_verify(fixture) }
    assert_match(/git ls-files reported nothing/, error.message)
  end

  test "a failing install fails" do
    fixture = build_fixture
    error = assert_raises(Verification::Failure) { run_verify(fixture, runner: ->(_env, *) { false }) }
    assert_match(/gem install failed/, error.message)
  end

  test "a failing version probe fails" do
    fixture = build_fixture
    results = [ true, false ]
    error = assert_raises(Verification::Failure) do
      run_verify(fixture, runner: ->(_env, *) { results.shift })
    end
    assert_match(/version probe failed/, error.message)
  end

  # --- CLI entry point --------------------------------------------------------

  test "run verifies and exits zero" do
    fixture = build_fixture
    err = StringIO.new
    built = nil
    factory = lambda { |file, name:, version:, out:|
      built = [ file, name, version ]
      verification(fixture, out: out)
    }

    status = Dir.chdir(fixture.source) do
      Verification.run([ fixture.gem_file, "upright", "0.1.0" ], out: @out, err: err, verification_for: factory)
    end
    assert_equal 0, status
    assert_equal [ fixture.gem_file, "upright", "0.1.0" ], built
  end

  test "run usage error exits two" do
    err = StringIO.new
    assert_equal 2, Verification.run([ "x.gem" ], out: @out, err: err)
    assert_match(/usage/, err.string)
  end

  test "run missing file exits two" do
    err = StringIO.new
    assert_equal 2, Verification.run([ File.join(@dir, "nope.gem"), "upright", "0.1.0" ], out: @out, err: err)
    assert_match(/no such file/, err.string)
  end

  test "run failure exits one" do
    fixture = build_fixture(version: "9.9.9")
    err = StringIO.new
    factory = lambda { |file, name:, version:, out:|
      Verification.new(file, name: name, version: "0.1.0", runner: ->(_env, *) { true },
                       reference: fixture.reference, tracked_files: fixture.tracked_files, out: out)
    }

    status = Verification.run([ fixture.gem_file, "upright", "0.1.0" ], out: @out, err: err, verification_for: factory)
    assert_equal 1, status
    assert_match(/verify_package: spec version/, err.string)
  end

  private
    Fixture = Struct.new(:gem_file, :source, :name, :version, :reference, :tracked_files, keyword_init: true)

    def verification(fixture, name: fixture.name, version: fixture.version,
                     runner: ->(_env, *) { true }, reference: fixture.reference, out: @out)
      Verification.new(fixture.gem_file, name: name, version: version, runner: runner,
                       reference: reference, tracked_files: fixture.tracked_files, out: out)
    end

    # The verifier's file-existence check is cwd-relative (in CI it runs from
    # the repo root), so verify from the fixture's source dir.
    def run_verify(fixture, **options)
      Dir.chdir(fixture.source) { verification(fixture, **options).verify! }
    end

    # Build a real gem from the given files in an isolated source dir. The
    # reference spec models the repo gemspec (same files unless told
    # otherwise), `packaged` narrows what actually gets built into the gem,
    # and `tracked` models `git ls-files`. The file-existence check runs
    # relative to the source dir, as it does from the repo root in CI.
    def build_fixture(name: "upright", version: "0.1.0", files: DEFAULT_FILES,
                      packaged: files.keys, tracked: files.keys,
                      dependencies: [], reference_dependencies: dependencies)
      source = File.join(@dir, "src-#{name}-#{version}-#{files.size}-#{packaged.size}-#{dependencies.size}")
      FileUtils.mkdir_p(source)

      built = Dir.chdir(source) do
        files.each do |path, content|
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, content)
        end

        spec = fixture_spec(name, version, packaged, dependencies)
        Gem::Package.build(spec, true)
      end

      reference = fixture_spec(name, version, files.keys, reference_dependencies)
      Fixture.new(
        gem_file: File.join(source, built), source: source, name: name, version: version,
        reference: -> { reference },
        tracked_files: -> { tracked }
      )
    end

    def fixture_spec(name, version, file_list, dependencies)
      Gem::Specification.new do |s|
        s.name = name
        s.version = version
        s.summary = "fixture"
        s.authors = [ "test" ]
        s.files = file_list
        dependencies.each { |dependency| s.add_dependency(*Array(dependency)) }
      end
    end
end
