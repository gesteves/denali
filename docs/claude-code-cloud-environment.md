# Claude Code cloud environment for Denali

How to set up a [Claude Code cloud environment](https://code.claude.com/docs/en/cloud-environments) that can build, lint and test Denali, so cloud sessions (claude.ai/code, the desktop and mobile apps, `claude --cloud`, scheduled tasks) can work on it.

Locally, Denali runs in Docker (`docker compose run --rm app …`). In a cloud session it runs directly on the session VM instead: the VM already has Postgres 16, Redis 7, Chrome and Docker, and building `Dockerfile.dev` there would need hosts the default network level doesn't allow (`deb.nodesource.com`, `deb.debian.org`).

## What the environment needs

| Need | Pre-installed? | Handled by |
| - | - | - |
| Ruby 4.0.9 (`.ruby-version`) | No, only 3.1–3.3 | Setup script: downloads the prebuilt Ubuntu 24.04 Ruby that `ruby/setup-ruby` uses |
| Node 22 (`.node-version`) | Yes, on `PATH` | — |
| `libpq-dev`, `libyaml-dev`, ImageMagick | Partly | Setup script: `apt-get install` |
| Gems and npm packages | No | Setup script (`bundle install`, `npm ci`); `start-services.sh` reinstalls if the checkout changed |
| PostgreSQL 16 | Installed, not running | Setup script allows passwordless local TCP; `start-services.sh` starts it, maps the `postgres` host in `config/database.yml` to `127.0.0.1` and runs `db:prepare` |
| Redis 7 | Installed, not running | `start-services.sh` |
| Elasticsearch 8.17 | No | Setup script pulls the Docker image; `start-services.sh --elasticsearch` runs it. Only the dev server uses it; tests don't |
| Chrome for system specs | Yes, `/usr/bin/google-chrome` | — |

Two files in this repo do the work:

- [`script/claude-cloud/setup.sh`](../script/claude-cloud/setup.sh): the environment's **setup script**. Runs as root before Claude Code starts, once per environment snapshot.
- [`script/claude-cloud/start-services.sh`](../script/claude-cloud/start-services.sh): run **in each session**. Starts the services (a snapshot keeps files, not running processes) and prepares the development and test databases. It exits immediately outside a cloud session.

## 1. Create the environment

1. Go to [claude.ai/code](https://claude.ai/code). On the new-session screen, select the environment selector (the first control under the message box), then **New environment**.
2. **Name**: `denali`.
3. **Network access**: **Trusted**. Everything the setup needs is on the default allowlist: `github.com` (the Ruby download, the `blurhash` git gem), `rubygems.org`, `registry.npmjs.org`, `archive.ubuntu.com` and Docker Hub.
4. **Setup script**: select **Choose file** and pick `script/claude-cloud/setup.sh` from a local checkout, or paste its contents.
5. **Environment variables**: none are needed for linting and tests. Optionally add:

   ```text
   BASH_DEFAULT_TIMEOUT_MS=600000
   BASH_MAX_TIMEOUT_MS=1200000
   ```

   so the full RSpec run doesn't get moved to the background at the default two-minute command timeout.
6. Select **Add environment**.

Start a session in the environment with this repository selected. The first session runs the setup script (about a minute, mostly `bundle install`); Claude Code snapshots the result and later sessions skip it. The script runs again when you change it or the network settings, and when the snapshot expires after about seven days.

## 2. Tell Claude to start the services

`CLAUDE.md` has a **Claude Code cloud sessions** section telling Claude to run `script/claude-cloud/start-services.sh` before it runs tests or Rails commands, and to skip `docker compose` in the cloud. You don't need to ask for it.

If you'd rather it run automatically on every session start, add a SessionStart hook to `.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/script/claude-cloud/start-services.sh" }
        ]
      }
    ]
  }
}
```

The script exits straight away when `CLAUDE_CODE_REMOTE` isn't `true`, so the hook is harmless locally. It adds about 15 seconds to each cloud session start.

## 3. Verify

Ask Claude, in a session in the new environment, to run the same checks CI runs:

```bash
script/claude-cloud/start-services.sh
```

```bash
RAILS_ENV=test bin/rails assets:precompile
```

```bash
bundle exec erb_lint --lint-all
```

```bash
bundle exec rspec
```

```bash
npm run lint
```

```bash
npm run test:coverage
```

`assets:precompile` builds the CSS and JS the system specs load; CI does the same before running RSpec.

## Running the dev server

Tests need no credentials, and the app boots in development without a `.env`. To run the dev server against Elasticsearch:

```bash
script/claude-cloud/start-services.sh --elasticsearch
```

```bash
bin/rails dartsass:build && npm run build
```

```bash
ELASTICSEARCH_URL=http://localhost:9200 bin/rails server -p 3000
```

Don't put `ELASTICSEARCH_URL` in the environment's variables: `Blog` turns search on whenever it's set, including in tests.

Features that call R2, Google OAuth or the social APIs need the keys in `.env.example`. Before adding any:

- **Environment variables are plain text** and readable by anyone who uses the environment. Use development keys, never production ones, and keep the environment personal (not shared with an organization).
- **Network secrets don't fit most of these.** The proxy can only attach a key as a request header. R2 (S3 SigV4 signing) and OAuth client secrets have to be inside the app process, so they'd have to be environment variables.

## Troubleshooting

- **Session fails to start with a setup-script error**: open the session's setup log. The script only exits non-zero if Ruby can't be installed, usually because `github.com` isn't reachable under the network level you picked.
- **`ruby -v` shows 3.3.6**: the setup script didn't run or failed before it linked Ruby into `/usr/local/bin`. Ask Claude to run `script/claude-cloud/setup.sh` from the repository's parent directory, or start a new session.
- **`bundler: command not found: <gem>`**: a gem executable wasn't linked onto `PATH`. `start-services.sh` relinks after any `bundle install` it runs; to do it by hand: `for f in "$(ruby -e 'print RbConfig::CONFIG["bindir"]')"/*; do ln -sf "$f" /usr/local/bin/; done`.
- **`could not translate host name "postgres"`**: run `start-services.sh`; it adds `postgres` to `/etc/hosts`.
- **Ruby version bump**: change `RUBY_VERSION` at the top of `setup.sh` along with `.ruby-version`, and update the environment's setup script. A new version needs a prebuilt `ubuntu-24.04-x64` build in [ruby/ruby-builder](https://github.com/ruby/ruby-builder/releases); `ruby/setup-ruby` usually has one within a day of a release.
