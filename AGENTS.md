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

