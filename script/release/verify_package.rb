# frozen_string_literal: true

# Build-job package verification, run on every build — rehearsals included.
#   ruby script/release/verify_package.rb GEM_FILE NAME VERSION
require_relative "package_verification"
exit Upright::Release::PackageVerification.run(ARGV)
