# syntax = docker/dockerfile:1

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t my-app .
# docker run -d -p 80:80 -p 443:443 --name my-app -e RAILS_MASTER_KEY=<value from config/master.key> my-app

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=<%= RUBY_VERSION %>
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages and Node.js (for Playwright)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips sqlite3 iputils-ping mtr-tiny \
    nodejs npm && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git pkg-config libssl-dev libyaml-dev rustc cargo libclang-dev && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN --mount=type=secret,id=GITHUB_TOKEN \
    BUNDLE_GITHUB__COM="$(cat /run/secrets/GITHUB_TOKEN):x-oauth-basic" bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile && \
    bundle exec ruby -e "require 'upright/version'; puts Upright::PLAYWRIGHT_VERSION" > /tmp/playwright_version

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app.rb probes/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Final stage for app image
FROM base

# Install Playwright before copying app code so the layer is cached on code-only deploys.
# The version is extracted to a file in the build stage; BuildKit's content-based caching
# keeps this layer cached even across Gemfile changes when the version is unchanged.
COPY --from=build /tmp/playwright_version /tmp/playwright_version
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
RUN PLAYWRIGHT_VERSION=$(cat /tmp/playwright_version) && \
    npm install -g playwright@~${PLAYWRIGHT_VERSION}.0 && \
    playwright install --with-deps chromium && \
    chmod -R o+rx /ms-playwright

# Copy built artifacts: gems, application
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p storage tmp && \
    chown -R rails:rails storage tmp
USER 1000:1000

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start the server by default, this can be overwritten at runtime
EXPOSE 3000 9394
CMD ["./bin/rails", "server"]
