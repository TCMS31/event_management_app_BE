# syntax=docker/dockerfile:1

# Multi-stage build. The `build` stage carries the compilers and headers needed
# for native gem extensions; the final stage carries only the runtime libraries,
# the compiled bundle and the application.

ARG RUBY_VERSION=3.2.2

# ---------------------------------------------------------------------------
# base -- shared by both stages
# ---------------------------------------------------------------------------
FROM docker.io/library/ruby:${RUBY_VERSION}-slim AS base

WORKDIR /rails

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    RAILS_LOG_TO_STDOUT="1"

# ---------------------------------------------------------------------------
# build -- gems only; nothing from here survives into the runtime image
# ---------------------------------------------------------------------------
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev pkg-config && \
    rm -rf /var/lib/apt/lists/*

# Copied before the source so a source-only change does not re-resolve the bundle.
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

COPY . .
RUN bundle exec bootsnap precompile app/ lib/

# ---------------------------------------------------------------------------
# runtime
# ---------------------------------------------------------------------------
FROM base

# `curl` is here for the healthcheck, `postgresql-client` for bin/docker-entrypoint.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libpq5 postgresql-client && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run as an unprivileged user. Only the directories Rails actually writes to
# are handed over.
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

EXPOSE 3000

# /up is Rails' built-in health endpoint (config/routes.rb). It touches the
# database, so an unhealthy container really is unhealthy.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl --fail --silent http://127.0.0.1:3000/up || exit 1

ENTRYPOINT ["/rails/bin/docker-entrypoint"]
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
