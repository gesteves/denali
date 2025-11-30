# Redis Sidekiq (denali-redis-sidekiq)

Redis instance for Sidekiq background jobs. Configured with no eviction to ensure jobs are never dropped due to memory pressure.

## Configuration

- **Memory**: 64MB max
- **Eviction Policy**: `noeviction` (return errors when full, never evict)
- **Persistence**: None (jobs may be lost on restart)

## Deploy

```bash
# First time setup
fly launch --no-deploy --name denali-redis-sidekiq --region iad --copy-config
fly deploy

# Subsequent deploys
fly deploy
```

## Common Commands

```bash
# Check status
fly status -a denali-redis-sidekiq

# View logs
fly logs -a denali-redis-sidekiq

# SSH into the container
fly ssh console -a denali-redis-sidekiq

# Connect to Redis CLI
fly ssh console -a denali-redis-sidekiq -C "redis-cli"

# Check memory usage
fly ssh console -a denali-redis-sidekiq -C "redis-cli INFO memory"

# View queued Sidekiq jobs
fly ssh console -a denali-redis-sidekiq -C "redis-cli LLEN queue:default"
fly ssh console -a denali-redis-sidekiq -C "redis-cli LLEN queue:high"
fly ssh console -a denali-redis-sidekiq -C "redis-cli LLEN queue:low"

# Stop the app (save money) - WARNING: stops job processing
fly scale count 0 -a denali-redis-sidekiq

# Start the app
fly scale count 1 -a denali-redis-sidekiq

```

## Connection

From other Fly apps in the same organization:
```
redis://denali-redis-sidekiq.internal:6379
```

Set in the main app:
```bash
fly secrets set REDIS_URL="redis://denali-redis-sidekiq.internal:6379" -a denali
```

