# Elasticsearch (denali-elasticsearch)

Elasticsearch 8.x instance for search functionality.

## Configuration

- **Version**: 8.17.0
- **Memory**: 1GB (512MB JVM heap)
- **Security**: Disabled (internal network only)
- **Persistence**: 1GB volume at `/usr/share/elasticsearch/data`

## Deploy

```bash
# First time setup
cd fly-elasticsearch
fly launch --no-deploy --name denali-elasticsearch --region iad --copy-config
fly volumes create elasticsearch_data --region iad --size 1 -a denali-elasticsearch
fly deploy

# Subsequent deploys
fly deploy
```

## Common Commands

```bash
# Check status
fly status -a denali-elasticsearch

# View logs
fly logs -a denali-elasticsearch

# Check cluster health
fly ssh console -a denali-elasticsearch -C "curl -s localhost:9200/_cluster/health?pretty"

# Check indices
fly ssh console -a denali-elasticsearch -C "curl -s localhost:9200/_cat/indices?v"

# Check node stats
fly ssh console -a denali-elasticsearch -C "curl -s localhost:9200/_nodes/stats?pretty"

# Stop (save money)
fly scale count 0 -a denali-elasticsearch

# Start
fly scale count 1 -a denali-elasticsearch
```

## Connection

From other Fly apps in the same organization:
```
http://denali-elasticsearch.internal:9200
```

Set in the main app:
```bash
fly secrets set ELASTICSEARCH_URL="http://denali-elasticsearch.internal:9200" -a denali
```

## Reindexing

After deploying, you need to reindex your data:

```bash
fly ssh console -a denali
cd /app
bin/rails runner "Entry.__elasticsearch__.create_index!(force: true)"
bin/rails runner "Entry.import"
```

Or use the rake task if available:
```bash
fly ssh console -a denali -C "cd /app && bin/rails elasticsearch:reindex"
```

## Troubleshooting

**ES won't start / OOM:**
- Increase memory in fly.toml
- Adjust ES_JAVA_OPTS heap size (should be ~50% of available memory)

**Slow startup:**
- ES 8.x takes 30-60 seconds to fully start
- Health checks have 60s grace period

**Index errors after upgrade:**
- Delete and recreate index: `Entry.__elasticsearch__.create_index!(force: true)`
- Reindex all data: `Entry.import`

