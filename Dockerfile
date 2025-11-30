# syntax=docker/dockerfile:1

# Base stage with Ruby and system dependencies
FROM ruby:3.4.7-slim AS base

WORKDIR /app

# Install base packages needed for both build and runtime
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    curl \
    gnupg \
    imagemagick \
    libpq5 \
    libvips42 \
    libyaml-0-2 \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Install Node.js and Yarn
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" > /etc/apt/sources.list.d/nodesource.list && \
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor -o /etc/apt/keyrings/yarn.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/yarn.gpg] https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list && \
    apt-get update -qq && \
    apt-get install -y --no-install-recommends nodejs yarn && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Set production environment
ENV RAILS_ENV="production" \
    NODE_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"


# Build stage for compiling assets
FROM base AS build

# Install packages needed to build gems and assets
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    git \
    libpq-dev \
    libyaml-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Install Gulp CLI for asset compilation
RUN yarn global add gulp-cli

# Install Ruby gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Install Node.js dependencies
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile --production=false

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Precompile assets
# SECRET_KEY_BASE is required for asset compilation but the value doesn't matter
RUN SECRET_KEY_BASE=dummy_key_for_asset_compilation bundle exec rails assets:precompile


# Production stage
FROM base AS production

# Install runtime packages only
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Copy built artifacts from build stage
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app

# Create non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER rails:rails

# Entrypoint prepares the database
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]


# Development stage (used by docker-compose)
FROM base AS development

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    git \
    libpq-dev \
    libyaml-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Reset environment for development
ENV RAILS_ENV="development" \
    NODE_ENV="development" \
    BUNDLE_DEPLOYMENT="" \
    BUNDLE_WITHOUT=""

# Install Gulp CLI
RUN yarn global add gulp-cli

WORKDIR /app

# Copy dependency files first for better layer caching
COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY package.json yarn.lock ./
RUN yarn install

COPY . .
