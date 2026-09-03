require "test_helper"

# The public 0.2.0 and 0.3.0 gems shipped config/credentials/development.key and
# test.key because the gemspec globbed the filesystem instead of reading the git
# index. These hold that line.
class PackagingTest < ActiveSupport::TestCase
  ROOT = Upright::Engine.root

  test "packages only files tracked by git" do
    assert_empty packaged_files - tracked_files
  end

  test "an ignored credential key can't enter the package" do
    key = ROOT.join("config/credentials/test.key")
    created = !key.exist?

    if created
      key.dirname.mkpath
      key.write(SecureRandom.hex(16))
    end

    assert_not_includes packaged_files, "config/credentials/test.key"
  ensure
    key.delete if created
  end

  test "packages the engine's runtime files" do
    assert_includes packaged_files, "lib/upright.rb"
    assert_includes packaged_files, "config/routes.rb"
    assert_includes packaged_files, "app/controllers/upright/application_controller.rb"
  end

  private
    def packaged_files
      Gem::Specification.load(ROOT.join("upright.gemspec").to_s).files
    end

    def tracked_files
      IO.popen(%w[git ls-files -z], chdir: ROOT.to_s) { |ls| ls.readlines("\x0", chomp: true) }
    end
end
