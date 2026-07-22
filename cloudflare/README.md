# Cloudflare

Cloudflare proxies the zone in front of the Rails app on Fly, stores photos in
R2, and runs the two Workers in this directory:

- [`images/`](images) — serves every image on the site (`denali-images`)
- [`plausible-proxy/`](plausible-proxy) — first-party analytics (`denali-plausible-proxy`)

Everything else is zone configuration, which lives in the Cloudflare dashboard
rather than in this repo. It is written down here because it is not discoverable
from the code, and because getting it wrong is silent — the site keeps working,
it just stops being cached.

## Caching HTML

**Cloudflare does not cache HTML by default.** Its default cache covers a fixed
list of [static file
extensions](https://developers.cloudflare.com/cache/concepts/default-cache-behavior/);
HTML is not among them, so without a Cache Rule every page view reaches Fly and
the `s-maxage` the app sends is ignored. (This bit us after the migration from
CloudFront, whose default behavior cached everything and honored the origin's
`Cache-Control`.) To check:

```bash
curl -sSI https://www.allencompassingtrip.com/ | grep -i cf-cache-status
```

`HIT` on a second request is what you want. `DYNAMIC` means the Cache Rule below
is missing or not matching.

### Cache Rule: "Cache HTML"

- **Expression**: the site's hostnames, excluding the bypass paths below.
- **Action**: *Eligible for cache*.
- **Edge TTL**: *Respect origin* — the app sends `s-maxage` from `CACHE_TTL`.
- **Vary**: `accept` → `normalize`. **This one is not optional.** Rails emits
  `Vary: Accept` from `respond_to`, and several actions answer a non-HTML
  `Accept` with a 301 (see the `format.all` branches in `EntriesController`).
  Cloudflare [ignores `Vary` unless it is configured
  here](https://developers.cloudflare.com/cache/concepts/vary/), so without it a
  bot's 301 can be cached at `/` and served to browsers.
- **Cache TTL by status**: `200` respect origin, `404` 1 minute, `3xx` do not
  cache — defence in depth for the same redirects.

### Cache Rule: bypass

Bypass cache for `/admin*`, `/signin`, `/signout`, `/auth*`, `/graphql`,
`/push-notifications/*`, `/random` and `/healthcheck`. The app also sends
`no-store` on all of these, so this is belt and braces.

### Tiered Cache

Enable it with the **Smart** topology (free on all plans). Fly is not one of the
providers that supports a [cloud region
hint](https://developers.cloudflare.com/cache/how-to/tiered-cache/#public-cloud-origins),
so this falls back to a generic topology, but it still cuts origin fetches given
the single Fly region.

## Purging

Pages are cached for `CACHE_TTL` (a day). That is a backstop, not the freshness
mechanism — `CachePurgeJob` is, and it purges by
[cache tag](https://developers.cloudflare.com/cache/how-to/purge-cache/purge-by-tags/):

| Tag | Attached to | Purged when |
|---|---|---|
| `entry-<id>` | an entry's permalink and its oembed | that entry is published, edited or deleted |
| `entries` | every list, feed and sitemap | any *published* entry changes |
| `blog` | about page, manifest, robots.txt, service worker | blog settings are saved in the admin |

See `app/lib/cache_tags.rb` for the vocabulary, `ApplicationController#set_cache_tags`
for where tags are attached, and `app/jobs/cache_purge_job.rb` for the purging.

The job needs two secrets, and does nothing without them — pages then go stale
for up to `CACHE_TTL`, quietly:

- `CLOUDFLARE_ZONE_ID`
- `CLOUDFLARE_API_TOKEN` — one permission, **Zone → Cache Purge → Purge**

Purging by tag is available on [all
plans](https://developers.cloudflare.com/changelog/post/2025-04-01-purge-for-all/).

## Origin protection

Cloudflare injects `X-Denali-Secret` on requests to Fly via a Transform Rule.
Requests that reach the origin without it are 301'd to the canonical domain —
see `ApplicationController#domain_redirect`, gated on `CDN_ORIGIN_PROTECTION`.
The `aet.to` short domain deliberately does *not* get the header, which is what
makes short links redirect.

Because Cloudflare presents the visitor's hostname as SNI, Fly needs a
certificate for each proxied hostname, not just the origin one:

```bash
fly certs add www.allencompassingtrip.com
```

Missing certificates surface as **SSL handshake failed, error 525**.
