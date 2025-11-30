# Redis Cache (denali-redis-cache)

Redis instance for Rails fragment/page caching. Configured with eviction policy to automatically remove old cache entries when memory is full.

## Configuration

- **Memory**: 64MB max
- **Eviction Policy**: `allkeys-lru` (evict least recently used keys)
- **Persistence**: None (cache can be lost on restart)

## Deploy

```bash
# First time setup
fly launch --no-deploy --name denali-redis-cache --region iad --copy-config
fly deploy

# Subsequent deploys
fly deploy
```

## Common Commands

```bash
# Check status
fly status -a denali-redis-cache

# View logs
fly logs -a denali-redis-cache

# SSH into the container
fly ssh console -a denali-redis-cache

# Connect to Redis CLI
fly ssh console -a denali-redis-cache -C "redis-cli"

# Check memory usage
fly ssh console -a denali-redis-cache -C "redis-cli INFO memory"

# Flush all cache
fly ssh console -a denali-redis-cache -C "redis-cli FLUSHALL"

# Stop the app (save money)
fly scale count 0 -a denali-redis-cache

# Start the app
fly scale count 1 -a denali-redis-cache
```

## Connection

From other Fly apps in the same organization:
```
redis://denali-redis-cache.internal:6379
```

Set in the main app:
```bash
fly secrets set REDIS_CACHE_URL="redis://denali-redis-cache.internal:6379" -a denali
```

