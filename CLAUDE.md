# Agent Instructions

## Docker Development Environment

This project runs in Docker. **All Rails, Ruby, and Node commands must be run inside the Docker container.**

### Running Commands

Use `docker compose run` to execute commands:

```bash
# Rails commands
docker compose run app rails db:migrate
docker compose run app rails console
docker compose run app bundle exec rspec
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
- `npm`, `node` (for app-related tasks)

The host machine may not have the correct Ruby version, gems, or database connectivity.

## SVG Icons

SVG icons are processed via a Rake task. To add or update icons:

1. Place the source SVG in `app/assets/images/svg/`
2. Run the rake task: `docker compose run app rake svg`
3. This strips inline styles/fills/strokes, adds ERB template variables, and outputs to `app/views/partials/svg/` as a partial

The resulting partial can be used with `<%= render 'partials/svg/icon_name', class_name: 'my-class', aria_hidden: true %>`.

## Testing

**All new functionality must have appropriate test coverage.** This applies to both Rails code (models, controllers, services) and JavaScript code (Stimulus controllers, utility functions).

### Ruby/Rails Tests (RSpec)

```bash
docker compose run app bundle exec rspec
docker compose run app bundle exec rspec spec/models/entry_spec.rb  # specific file
docker compose run app bundle exec rspec spec/models/entry_spec.rb:42  # specific line
```

### JavaScript Tests (Vitest)

Stimulus controllers and utility functions are tested with Vitest. Test files are colocated with source files using the `.test.js` suffix.

```bash
docker compose run app npm run test:run                                    # run all tests
docker compose run app npm test                                            # run in watch mode
docker compose run app npm run test:coverage                               # run with coverage
docker compose run app npx vitest run app/frontend/lib/utils.test.js       # specific file
```

Test infrastructure:
- `vitest.config.js` - Vitest configuration
- `app/frontend/test/setup.js` - Global mocks (IntersectionObserver, fetch, etc.)
- `app/frontend/test/helpers.js` - Test utilities for Stimulus controllers

## Fly.io Deployment

This app is deployed on [Fly.io](https://fly.io). The main app configuration is in `fly.toml`.

**Do NOT deploy from Claude Code.** The terminal output consumes excessive tokens. The user will deploy manually.

### Common Commands

```bash
# Deploy the app
fly deploy

# View app logs
fly logs

# SSH into the running app
fly ssh console

# Run a Rails console on production
fly ssh console -C "rails console"

# Check app status
fly status

# Scale the app (number of machines)
fly scale count 2
fly scale count web=2 worker=1

# Scale machine size
fly scale vm shared-cpu-1x

# View current scale settings
fly scale show
```

### Separate Fly.io Apps

The `fly-*` directories contain separate Fly.io applications that support the main app:

- `fly-elasticsearch/` - Elasticsearch service
- `fly-redis-cache/` - Redis for caching
- `fly-redis-sidekiq/` - Redis for Sidekiq job queue
- `fly-thumbor/` - Thumbor image processing service

To deploy or manage these services, `cd` into the respective directory and run Fly commands from there:

```bash
cd fly-thumbor
fly deploy
fly logs
```
