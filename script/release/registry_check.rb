# frozen_string_literal: true

# Publish-job reconciliation: prints "push" or "skip", or fails closed.
#   ruby script/release/registry_check.rb NAME VERSION SHA256
require_relative "registry"
exit Upright::Release::Registry.run_check(ARGV)
