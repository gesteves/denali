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

## The visitor IP

Plausible derives the visitor hash and the reported country/city from the client
IP, which it reads from the first of these headers that is present:

    X-Plausible-IP → CF-Connecting-IP → B-Forwarded-For → X-Forwarded-For → Forwarded

The Worker sets **`X-Plausible-IP`** from `CF-Connecting-IP`. That's deliberate:
it's the only one of those headers no proxy in the chain rewrites. `CF-Connecting-IP`
looks like it would do the job — a Worker subrequest inherits the real visitor IP in
it — but [only for subrequests to non-Cloudflare
origins](https://developers.cloudflare.com/fundamentals/reference/http-headers/).
`plausible.io` is served by BunnyCDN today (which is also why Plausible checks
Bunny's `B-Forwarded-For`); if it ever moved behind Cloudflare, this would become a
cross-zone subrequest and `CF-Connecting-IP` would be replaced with a fixed Worker
IP that still outranks `X-Forwarded-For` — silently geolocating every visitor to the
same place. `X-Forwarded-For` is set too, but it's the weakest of the three and
can't be relied on alone.

Any client-supplied `X-Plausible-IP` is deleted before ours is set — the forwarded
request is built from the inbound one, so it carries every header the browser sent.

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

`src/index.test.js` covers the routing, the IP headers, and the caching without
touching the network:

```bash
docker compose run --rm app npx vitest run cloudflare/plausible-proxy
```

It runs in the `workers` vitest project, which uses the node environment rather
than the frontend's jsdom — jsdom's `Request` drops the method and headers of a
`Request` passed as init, which is how the Worker builds its upstream request.

## Logs

```bash
npx wrangler tail denali-plausible-proxy
```
