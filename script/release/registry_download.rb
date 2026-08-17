# frozen_string_literal: true

# Recovery-path download: fetches the canonical .gem bytes for a published
# version, verifies them against the digest the registry itself reports,
# writes them to DESTINATION, and prints the digest.
#   ruby script/release/registry_download.rb NAME VERSION DESTINATION
require_relative "registry"
exit Upright::Release::Registry.run_download(ARGV)
