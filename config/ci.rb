# Run using bin/ci

CI.run do
  step "Style: Ruby", "bin/rubocop"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Lint: GitHub Actions (actionlint)", "actionlint"
  step "Lint: GitHub Actions (zizmor)", "zizmor ."
  step "Tests: Rails", "bin/rails test"
end
