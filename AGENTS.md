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
docker compose run app rails generate model Foo name:string
docker compose run app rails generate migration AddBarToFoo bar:integer

# Bundle install
docker compose run app bundle install

# Rake tasks
docker compose run app rake <task>

# Interactive shell
docker compose run app bash
```

### Starting the Environment

```bash
docker compose up -d          # Start all services in background
docker compose down           # Stop all services
docker compose logs -f app    # Follow app logs
```

### Do NOT Run Locally

Do not attempt to run these commands directly on the host machine:
- `rails`, `rake`, `bundle`, `ruby`
- `yarn`, `npm`, `node` (for app-related tasks)

The host machine may not have the correct Ruby version, gems, or database connectivity.

## Testing

Uses Minitest (Rails default). Run tests with:

```bash
docker compose run app rails test
docker compose run app rails test test/models/entry_test.rb  # specific file
```

