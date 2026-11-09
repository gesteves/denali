#!/bin/bash
# Starts the services Denali needs in a Claude Code cloud session and prepares
# the databases. Safe to run more than once. Does nothing outside the cloud.
#
#   script/claude-cloud/start-services.sh                  # Postgres + Redis
#   script/claude-cloud/start-services.sh --elasticsearch  # ...and Elasticsearch
#
# The environment's setup script (script/claude-cloud/setup.sh) installs
# everything; this starts what the environment snapshot can't keep running.
set -uo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  echo "Not a Claude Code cloud session; use docker compose instead." >&2
  exit 0
fi

cd "$(dirname "$0")/../.." || exit 1
log() { echo "==> $*"; }

# config/database.yml connects to a host named "postgres", as in Docker.
grep -qE '^127\.0\.0\.1\s.*\bpostgres\b' /etc/hosts || echo '127.0.0.1 postgres' >> /etc/hosts

service postgresql start >/dev/null && log "Postgres running"
service redis-server start >/dev/null && log "Redis running"

if [ "${1:-}" = "--elasticsearch" ]; then
  if ! docker info >/dev/null 2>&1; then
    (dockerd >/var/log/dockerd.log 2>&1 &)
    for _ in $(seq 1 30); do docker info >/dev/null 2>&1 && break; sleep 1; done
  fi
  if ! docker start denali-elasticsearch >/dev/null 2>&1; then
    docker run -d --name denali-elasticsearch -p 9200:9200 \
      -e discovery.type=single-node -e xpack.security.enabled=false \
      -e xpack.ml.enabled=false -e ES_JAVA_OPTS='-Xms512m -Xmx512m' \
      elasticsearch:8.17.0 >/dev/null
  fi
  log "Elasticsearch starting on http://localhost:9200 (set ELASTICSEARCH_URL to use it)"
fi

# node_modules lives in the checkout, which may be newer than the snapshot.
hashes=node_modules/.claude-cloud.sha256
if ! sha256sum --check --status "$hashes" 2>/dev/null; then
  rm -f "$hashes"
  npm ci --no-audit --no-fund --loglevel=error && sha256sum package.json package-lock.json > "$hashes"
fi
if ! bundle check >/dev/null 2>&1; then
  bundle install --jobs 4 --quiet
  # bundle exec finds gem executables on PATH; the Ruby bin dir isn't on it.
  for f in "$(ruby -e 'print RbConfig::CONFIG["bindir"]')"/*; do ln -sf "$f" /usr/local/bin/; done
fi

for env in development test; do
  RAILS_ENV=$env bin/rails db:prepare >/dev/null && log "$env database ready"
done
