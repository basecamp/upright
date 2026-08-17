# frozen_string_literal: true

# Confirm-job verification: bounded poll until the registry reports exactly
# our version with exactly our digest, then downloads the canonical bytes and
# verifies those too.
#   ruby script/release/registry_confirm.rb NAME VERSION SHA256 [DEADLINE_SECONDS]
require_relative "registry"
exit Upright::Release::Registry.run_confirm(ARGV)
