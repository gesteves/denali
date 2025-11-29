# Agent Instructions

## Docker Development Environment

This project runs in Docker. **All Rails, Ruby, and Node commands must be run inside the Docker container.**

### Running Commands

Use `docker compose run` to execute commands:

```bash
# Rails commands
docker compose run app rails db:migrate
docker compose run app rails console
docker compose run app rails test

# Bundle commands
docker compose run app bundle install
docker compose run app bundle exec rake <task>

# Interactive shell
docker compose run app bash
```

### Starting the Environment

```bash
docker compose up -d          # Start all services in background
docker compose down           # Stop all services
docker compose logs -f app    # Follow app logs
```

### Services

- **app**: Rails web server (port 3000)
- **sidekiq**: Background job processor
- **webpacker**: Webpack dev server (port 3035)
- **postgres**: PostgreSQL 17 database
- **redis**: Redis 7 for caching/jobs
- **elasticsearch**: Elasticsearch 5.6 for search

### Do NOT Run Locally

Do not attempt to run these commands directly on the host machine:
- `rails`, `rake`, `bundle`, `ruby`
- `yarn`, `npm`, `node` (for app-related tasks)

The host machine may not have the correct Ruby version, gems, or database connectivity.

## Tech Stack

- **Ruby**: 3.4.7
- **Rails**: 8.0.4
- **Database**: PostgreSQL 17
- **Search**: Elasticsearch 5.6 with `elasticsearch-model` gem
- **Background Jobs**: Sidekiq with `sidekiq-scheduler`
- **Frontend**: Webpacker, Turbolinks, Sass
- **Caching**: Redis, Memcached (Dalli)
- **File Storage**: Active Storage with AWS S3
- **API**: GraphQL (see `app/graphql/`)

## Testing

Uses Minitest (Rails default). Run tests with:

```bash
docker compose run app rails test
docker compose run app rails test test/models/entry_test.rb  # specific file
```

Sidekiq jobs are faked in tests via `Sidekiq::Testing.fake!`.

## Environment Variables

Uses Figaro for configuration. Environment variables are set in:
- `.env` file (for Docker Compose)
- `config/application.yml` (for Figaro, not committed)

## Key Models

- **Entry**: Blog posts/entries (the main content model)
- **Photo**: Images attached to entries (uses Active Storage)
- **Blog**: Blog configuration
- **Tag/TagCustomization**: Entry tagging via `acts-as-taggable-on`

## Background Workers

Located in `app/workers/`. Key workers include:
- Social media posting: `BlueskyWorker`, `MastodonWorker`, `ThreadsWorker`, `InstagramWorker`
- Image processing: `BlurhashWorker`, `ColorDetectionWorker`, `PhotoExifWorker`
- Search indexing: `ElasticsearchWorker`

## Frontend JavaScript

Stimulus controllers are in `app/frontend/controllers/`. Uses Webpacker for bundling.

