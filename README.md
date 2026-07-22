# Denali

![CI](https://github.com/gesteves/denali/actions/workflows/ci.yml/badge.svg?branch=release)

A simple, fast photoblogging CMS built in Ruby on Rails which features responsive, high-resolution images. You can see it live at [All-Encompassing Trip](http://www.allencompassingtrip.com).

## Features

* Simple, streamlined entry editor
* Customizable publishing schedule
* Drag-and-drop organization of queued entries
* Cross-posting of entries to Bluesky, Mastodon, Flickr, Instagram, and Threads
* Auto-tagging of entries by location, camera, lens, film, and style
* Automatic generation of [blurhashes](https://blurha.sh/) for image placeholders
* AI-generated alt text for photos using Claude
* Full-text search powered by Elasticsearch
* Web push notifications
* Webhooks
* Automatic EXIF extraction and geotagging of photos
* Location tagging via Google Maps, the National Park Service, and Native Land APIs
* Admin map view powered by Mapbox GL JS
* GraphQL API
* Automated daily database backups to Cloudflare R2
* RSS/Atom feeds, sitemaps, and Open Graph tags
* Did I mention it's fast as heck?

## Requirements

* [Docker](https://www.docker.com/) and Docker Compose (for local development)
* A [Cloudflare](https://www.cloudflare.com/) account with an R2 bucket for image storage, Image Transformations enabled on the zone, and the domain proxied through Cloudflare
* A [Google Cloud](https://console.cloud.google.com/) project with OAuth 2.0 credentials for admin authentication

See `.env.example` for all required and optional environment variables.

## Installation & setup

1. Clone the repository:

   ```bash
   git clone https://github.com/gesteves/denali.git
   cd denali
   ```

2. Copy the example environment file and fill in the required values:

   ```bash
   cp .env.example .env
   ```

3. Build and start the Docker containers:

   ```bash
   docker compose up -d --build
   ```

4. Set up the database:

   ```bash
   docker compose run --rm app rails db:setup
   ```

5. Visit [http://localhost:3000](http://localhost:3000).

## Common tasks

### Local development

The app runs in Docker. All Rails, Ruby, and Node commands must be run inside the container.

#### Starting the environment

```bash
docker compose up -d          # Start all services in background
docker compose down           # Stop all services
docker compose logs -f app    # Follow app logs
```

#### Building

```bash
docker compose build                    # Build/rebuild containers
docker compose build --no-cache         # Full rebuild (no cache)
docker compose up -d --build            # Rebuild and start
```

#### Running commands

```bash
docker compose run --rm app rails console                 # Rails console
docker compose run --rm app rails db:migrate              # Run migrations
docker compose run --rm app bundle exec rspec             # Run tests
docker compose run --rm app rake <task>                   # Run rake tasks
docker compose run --rm app bundle install                # Install gems
docker compose run --rm app bash                          # Interactive shell
```

#### Running tests

```bash
# Ruby/Rails (RSpec)
docker compose run --rm app bundle exec rspec
docker compose run --rm app bundle exec rspec spec/models/entry_spec.rb      # Specific file
docker compose run --rm app bundle exec rspec spec/models/entry_spec.rb:42   # Specific line

# JavaScript (Vitest)
docker compose run --rm app npm run test:run              # Run all tests
docker compose run --rm app npm test                      # Watch mode
docker compose run --rm app npm run test:coverage         # With coverage
```

#### Troubleshooting

```bash
# Reset the database
docker compose run --rm app rails db:reset

# Clear Rails cache
docker compose run --rm app rails tmp:clear

# Recreate containers from scratch
docker compose down
docker compose up -d --build --force-recreate

# Remove all volumes (deletes local database!)
docker compose down -v

# View container status
docker compose ps

# Check container resource usage
docker compose top
```

### Production

#### Deploying

```bash
fly deploy
```

#### Viewing logs

```bash
fly logs
```

#### SSH into the app

```bash
fly ssh console
```

#### Rails console

```bash
fly ssh console -C "/app/bin/rails console"
```

#### Running migrations

Migrations run automatically on deploy, but to run manually:

```bash
fly ssh console -C "/app/bin/rails db:migrate"
```

#### Running rake tasks

```bash
fly ssh console -C "/app/bin/rake <task_name>"
```

#### Scaling

```bash
# Check current scale
fly scale show

# Scale web & worker machines (count)
fly scale count web=2 worker=2

# Scale machine size
fly scale vm shared-cpu-2x --memory 2048

# Scale worker memory
fly scale memory 2gb -a denali --process-group worker
fly scale memory 1gb -a denali --process-group worker
```

#### Backing up the database

The app automatically creates daily database backups and uploads them to Cloudflare R2.

**Automated backups:**
- Runs daily at 9:00 AM
- Creates PostgreSQL custom format dumps (`.dump` files)
- Uploads to the R2 bucket specified in `DB_BACKUP_BUCKET`
- Only runs in production when `DB_BACKUP_BUCKET` and `DATABASE_URL` are set

**Create a backup manually:**

```bash
fly ssh console -C "rake database:backup"
```

**Download the most recent backup:**

```bash
# Locally (downloads to project root, requires DB_BACKUP_BUCKET and R2 credentials)
docker compose run --rm app rake database:download
```

**Restore a backup:**

```bash
pg_restore -d database_name denali_backup_YYYYMMDD_HHMMSS.dump
```

**Required environment variables:**
- `DB_BACKUP_BUCKET` - R2 bucket name for backups
- `DATABASE_URL` - Postgres connection string (automatically set by Fly.io)
- R2 credentials and endpoint (`R2_ACCESS_KEY_ID`/`R2_SECRET_ACCESS_KEY`/`R2_ENDPOINT`)
