#!/bin/bash
# Setup script for a Claude Code cloud environment that runs Denali.
#
# Paste this into the environment's "Setup script" box (or load it with
# "Choose file"). It runs as root on Ubuntu 24.04 before Claude Code starts,
# and its result is snapshotted, so it has to finish in about five minutes and
# exit zero. Services (Postgres, Redis, Elasticsearch) can't be started here:
# the snapshot keeps files, not processes. script/claude-cloud/start-services.sh
# starts them in each session. See docs/claude-code-cloud-environment.md.
set -uo pipefail

RUBY_VERSION=4.0.9
ES_IMAGE=elasticsearch:8.17.0
log() { echo "==> [denali-setup] $*"; }

# The script starts in the directory that holds the checkouts; find Denali.
APP_DIR=""
for d in denali "$PWD" /home/user/denali; do
  if [ -f "$d/Gemfile" ] && grep -q 'denali' "$d/fly.toml" 2>/dev/null; then
    APP_DIR="$(cd "$d" && pwd)"; break
  fi
done

# 1. System packages: libpq-dev for the pg gem; libyaml-dev for psych;
#    ImageMagick for mini_magick. Runs in the background alongside the rest.
(
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq && apt-get install -y -qq --no-install-recommends \
    libpq-dev libyaml-dev imagemagick >/dev/null && log "apt packages installed"
) &
APT_PID=$!

# 2. Elasticsearch image, pulled in the background so the snapshot has it.
(
  if ! docker info >/dev/null 2>&1; then
    (dockerd >/var/log/dockerd.log 2>&1 &)
    for _ in $(seq 1 30); do docker info >/dev/null 2>&1 && break; sleep 1; done
  fi
  docker pull -q "$ES_IMAGE" >/dev/null && log "pulled $ES_IMAGE"
) &
ES_PID=$!

# 3. Ruby: the image only ships 3.1-3.3. Use the prebuilt Ubuntu 24.04 build
#    that ruby/setup-ruby uses (on github.com, which the Trusted network level
#    allows), instead of compiling from source. It's built for, and must live
#    in, the GitHub Actions tool cache path; /opt/ruby-X links to it, matching
#    how the image lays out its own Rubies.
RUBY_PREFIX=/opt/hostedtoolcache/Ruby/$RUBY_VERSION/x64
if [ ! -x "$RUBY_PREFIX/bin/ruby" ]; then
  log "installing Ruby $RUBY_VERSION"
  mkdir -p "$(dirname "$RUBY_PREFIX")"
  curl -fsSL "https://github.com/ruby/ruby-builder/releases/download/ruby-$RUBY_VERSION/ruby-$RUBY_VERSION-ubuntu-24.04-x64.tar.gz" \
    | tar -xz -C "$(dirname "$RUBY_PREFIX")"
fi
rm -rf "/opt/ruby-$RUBY_VERSION"
ln -sfn "$RUBY_PREFIX" "/opt/ruby-$RUBY_VERSION"
# Make it the default ruby, the same way the image wires up its own Rubies.
for f in /opt/ruby-$RUBY_VERSION/bin/*; do ln -sf "$f" /usr/local/bin/; done
cat > /usr/local/bin/use-ruby-$RUBY_VERSION <<SH
#!/bin/bash
export PATH="/opt/ruby-$RUBY_VERSION/bin:\$(echo \$PATH | sed 's|/opt/ruby-[^:]*bin:||g')"
ruby --version
SH
chmod +x /usr/local/bin/use-ruby-$RUBY_VERSION
ruby --version || { log "Ruby install failed"; exit 1; }

wait $APT_PID || log "WARNING: apt install failed"

# 4. Postgres: config/database.yml connects as postgres, without a password,
#    over TCP. Trust local TCP connections, as the Docker setup does.
PG_HBA=$(ls /etc/postgresql/*/main/pg_hba.conf 2>/dev/null | head -1)
if [ -n "$PG_HBA" ]; then
  sed -i -E 's/^(host\s+all\s+all\s+(127\.0\.0\.1\/32|::1\/128)\s+)\S+/\1trust/' "$PG_HBA"
fi

# 5. Gems and npm packages. Gems land in /opt/ruby-*, which the snapshot
#    keeps; start-services.sh reinstalls node_modules if it's missing.
if [ -n "$APP_DIR" ]; then
  cd "$APP_DIR"
  gem install bundler -v "$(tail -1 Gemfile.lock | tr -d ' ')" --no-document -q || true
  bundle install --jobs 4 --retry 3 --quiet && log "bundle install done" || log "WARNING: bundle install failed"
  npm ci --no-audit --no-fund --loglevel=error && log "npm ci done" || log "WARNING: npm ci failed"
else
  log "Denali checkout not found; skipping bundle/npm installs"
fi

# Link gem executables (rspec, erb_lint, ...) onto PATH too. bundle exec looks
# them up on PATH, and the Ruby bin directory isn't on it.
for f in /opt/ruby-$RUBY_VERSION/bin/*; do ln -sf "$f" /usr/local/bin/; done

wait $ES_PID || log "WARNING: couldn't pull $ES_IMAGE; search won't work in dev"
log "done"
exit 0
