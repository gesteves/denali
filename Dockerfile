# syntax=docker/dockerfile:1
# Production Dockerfile for Fly.io

FROM ruby:4.0.1-slim AS base

WORKDIR /app

# Install base packages needed for runtime
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    curl \
    gnupg \
    imagemagick \
    libpq5 \
    libvips42 \
    libyaml-0-2 \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Install Node.js
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" > /etc/apt/sources.list.d/nodesource.list && \
    apt-get update -qq && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

ENV RAILS_ENV="production" \
    NODE_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"


# Build stage
FROM base AS build

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    git \
    libpq-dev \
    libyaml-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

RUN npm install -g gulp-cli

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

RUN bundle exec bootsnap precompile app/ lib/

# Precompile assets (jsbundling-rails runs npm run build automatically)
RUN SECRET_KEY_BASE=dummy_key_for_asset_compilation \
    RAILS_SERVE_STATIC_FILES=true \
    bundle exec rails assets:precompile


# Production stage
FROM base

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    postgresql-client \
    locales \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p db log storage tmp && \
    chown -R rails:rails /app
USER rails:rails

EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
