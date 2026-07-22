# Plausible proxy

A Cloudflare Worker that serves [Plausible Analytics](https://plausible.io) as
first-party requests, so content blockers that filter `plausible.io` don't drop
them:

| Path | Proxies to |
|------|------------|
| `/pa/script.js` | The site's personalized Plausible script (edge-cached for 6 hours) |
| `/pa/event` | `https://plausible.io/api/event` |

The `/pa/` prefix matches [Kona](https://github.com/gesteves/kona) and avoids
`/js/` and `/api/`, which the zone's WAF rules block.

Two things reference these paths:

- `app/frontend/lib/analytics.js` posts events to `/pa/event`.
- The `<script>` tag lives in the database, in the blog's **analytics head**
  field (editable in the admin under blog settings), and should be
  `<script defer src="/pa/script.js"></script>`.

## Deploying

```bash
cd cloudflare/plausible-proxy
npx wrangler deploy
```

The Worker takes its route and its `PLAUSIBLE_SCRIPT_URL` from
`wrangler.jsonc`. If Plausible ever reissues the personalized script URL (shown
under **Site Installation** in the Plausible dashboard), update that value and
redeploy — the `<script>` tag in the database doesn't change.

## Local development

```bash
npx wrangler dev
```

Then request `http://localhost:8787/pa/script.js`. Note that `/pa/event` will
record real pageviews in Plausible, so avoid hammering it.

## Logs

```bash
npx wrangler tail denali-plausible-proxy
```
