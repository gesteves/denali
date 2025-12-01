# Denali

A simple, fast photoblogging CMS built in Ruby on Rails which features responsive, high-resolution images. You can see it live at [All-Encompassing Trip](http://www.allencompassingtrip.com).

## Features

### A simple, streamlined entry editor

![](https://i.imgur.com/N42IOxI.png)

### A customizable publishing schedule

![](https://i.imgur.com/ax4Bs8X.png)

### Drag-and-drop organization of queued entries

![](https://i.imgur.com/lSiV4Ro.png)

### Map view of entries

![](https://i.imgur.com/enMdop1.png)

### More features

* Cross-posting of entries to Bluesky, Mastodon, Flickr, Instagram, and Threads
* Auto-tagging of entries by location, equipment, and style
* Automatic generation of [blurhashes](https://blurha.sh/) for image placeholders
* Web push notifications
* Webhooks
* Automatic EXIF extraction and geotagging of photos
* GraphQL API
* Did I mention it's fast as heck?

## Requirements

[TODO]

## Installation & setup

[TODO]

## Common tasks

### Deploying

```bash
fly deploy
```

### Viewing logs

```bash
fly logs
```

### SSH into the app

```bash
fly ssh console
```

### Rails console

```bash
fly ssh console -C "/app/bin/rails console"
```

### Running migrations

Migrations run automatically on deploy, but to run manually:

```bash
fly ssh console -C "/app/bin/rails db:migrate"
```

### Running rake tasks

```bash
fly ssh console -C "/app/bin/rake <task_name>"
```

### Scaling

```bash
# Check current scale
fly scale show

# Scale web & worker machines (count)
fly scale count web=2 worker=2

# Scale machine size
fly scale vm shared-cpu-2x --memory 2048
```

### Backing up the database

The app uses Fly.io Managed Postgres, which includes automated backups. To create a manual backup:

1. Open a proxy to the Managed Postgres cluster:

```bash
fly mpg proxy
```

2. In another terminal, run `pg_dump` against the proxy:

```bash
pg_dump "postgres://fly-user:<password>@localhost:16380/fly-db" \
  --no-owner \
  --no-acl \
  -F c \
  -f denali_backup_$(date +%Y%m%d).dump
```

Replace `<password>` with the `fly-user` password for the Managed Postgres cluster.
