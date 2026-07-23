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
the TTL the app sends is ignored. (This bit us after the migration from
CloudFront, whose default behavior cached everything and honored the origin's
`Cache-Control`.) To check:

```bash
curl -sSI https://www.allencompassingtrip.com/ | grep -i cf-cache-status
```

`HIT` on a second request is what you want. `DYNAMIC` means "Cache HTML" below is
missing or not matching.

Entry pages send both an `ETag` and a `Last-Modified` (see the `stale?` call in
`EntriesController#show`), but Cloudflare strips the `ETag` from HTML on its way
to the client — it recompresses the response, and weak validators don't survive
that unless **Respect strong ETags** is enabled. Conditional GETs still work
through `Last-Modified`, so this costs nothing; just don't go looking for an
`ETag` on an HTML response and conclude something is broken.

### The Cache Rules

Three rules, and **the order is load-bearing**. Cache Rules are non-terminating:
every matching rule contributes its settings, and [where two rules set the same
one, the later rule
wins](https://developers.cloudflare.com/rules/transform/request-header-modification/#execution-order).
So each rule below narrows the one above it.

#### 1. "Bypass dynamic endpoints" — *first*

*Bypass cache* for `/graphql` and `/push-notifications/subscription`. Both are
POST endpoints whose responses are per-request, and `/graphql`'s cache key would
miss the `Authorization` header entirely. The app also sends `no-store` on both,
so this is belt and braces.

#### 2. "Cache HTML" — *after "Bypass dynamic endpoints"*

- **Expression**: `http.host` in `allencompassingtrip.com` /
  `www.allencompassingtrip.com`, minus the paths that must never be cached —
  `/admin`, `/signin`, `/signout`, `/graphql`, `/random`, `/healthcheck`,
  `/admin/*`, `/auth/*`, `/push-notifications/*` — and minus the Worker routes
  `/images/*`, `/ig/*` and `/pa/*`, which [cache themselves](#caching-in-the-workers).
  Excluded paths report `cf-cache-status: DYNAMIC` (not `BYPASS`, which would
  mean a rule matched and chose to bypass).
- **Cache eligibility**: *Eligible for cache*.
- **Edge TTL**: *Use cache-control header if present, bypass cache if not* — the
  app sends its edge directives in `Cloudflare-CDN-Cache-Control`, built from
  `CACHE_TTL`. See [Serving stale](#serving-stale) for why they aren't in
  `s-maxage`.
- **Status code TTL**: `400–499` → 1 minute, so scanners are absorbed at the
  edge. `300–308` → *No cache*, which is defence in depth for the redirects the
  `Vary` setting below is really about.
- **Vary**: *Normalize values*, with `accept` configured explicitly. **This one
  is not optional.** Rails emits `Vary: Accept` from `respond_to`, and several
  actions answer a non-HTML `Accept` with a 301 (see the `format.all` branches
  in `EntriesController`). Cloudflare [ignores `Vary` unless it is configured
  here](https://developers.cloudflare.com/cache/concepts/vary/), so without it a
  bot's 301 can be cached at `/` and served to browsers.
- **Serve stale content while revalidating**: leave unset. Unset means Cloudflare
  *does* serve stale, which is what we want — the setting exists to turn that
  off. Adding it disabled would undo half of [Serving stale](#serving-stale)
  from the dashboard, invisibly to the app.

#### 3. "Cache short links" — *last*

- **Expression**: `http.host in {"allencompassingtrip.com"
  "www.allencompassingtrip.com"} and starts_with(http.request.uri.path, "/p/")`
- **Cache eligibility**: *Eligible for cache*.
- **Edge TTL**: *Use cache-control header if present, bypass cache if not*, with
  a **Status code TTL** of `300–308` → 1 year.

Short links are the URLs that get shared, so they take the burst when a post
goes anywhere. They match "Cache HTML", which marks them cacheable and then
refuses to store them via its `300–308 → No cache` — so every share-click
reaches Fly for a redirect the edge could have answered. `cf-cache-status: MISS`,
every time. This rule runs last, so its status code TTL replaces that one.

It doesn't reopen the redirect-caching hole the blanket setting defends against.
That hole is the `format.all` branches in `EntriesController`, which answer a
non-HTML `Accept` with a 301 to the URL the browser already asked for.
`EntriesController#short` has no `respond_to` at all: it 301s to the entry's
permalink regardless of `Accept`, and already sends a year-long `immutable`
`Cache-Control` of its own. There is only one right answer to cache.

One caveat to know about: unlike every other cached page, this redirect carries
no `Cache-Tag` — `EntriesController#short` calls neither `set_max_age` nor
`set_cache_tags` — so `CachePurgeJob` can't reach it. If an entry's slug
changes, the cached 301 points at the old one until it expires. That costs a
second redirect rather than a broken link, since `EntriesController#show`
redirects a non-canonical path to the permalink. Adding
`set_cache_tags(CacheTags.entry(entry.id))` to `short` would make it purgeable
and is worth doing if the year ever proves too long.

### Serving stale

The app's HTML carries two cache headers, and the split matters:

- `Cache-Control: max-age=0, public` — what browsers get. They always
  revalidate, so a purge is never defeated by a stale copy we can't reach.
- `Cloudflare-CDN-Cache-Control: public, max-age=<CACHE_TTL>,
  stale-while-revalidate=…, stale-if-error=…` — what Cloudflare caches on. It
  [outranks
  `Cache-Control`](https://developers.cloudflare.com/cache/concepts/cdn-cache-control/)
  and is stripped before the response reaches a client, so its absence from a
  `curl -I` is the proof it was consumed, not a sign it went missing.

The edge directives are *not* in `s-maxage`, and must not be moved back. Per
[RFC 9111 §4.2.4](https://www.rfc-editor.org/rfc/rfc9111#section-4.2.4),
`s-maxage` implies `proxy-revalidate`, and Cloudflare therefore **disables both
`stale-while-revalidate` and `stale-if-error`** when it sees one. That was the
behavior here until the stale directives were added: every lapsed TTL made a
visitor wait on a Rails render from a single `iad` machine, and a Fly outage or
a slow deploy was an outage for the site. The same applies to `must-revalidate`
and `proxy-revalidate` — keep all three off the response.

Serving stale doesn't weaken purging. A purge *deletes* the cached entry, so a
purged page is a true `MISS` that goes to the origin; the stale window only ever
covers a TTL that lapsed on its own and an origin that failed.

See `ApplicationController#set_max_age`. `UPDATING` in `cf-cache-status` is what
stale-while-revalidate looks like in the wild; if you never see it, something
put an `s-maxage` back on the response.

### Tiered Cache

Enable it with the **Smart** topology (free on all plans). Fly is not one of the
providers that supports a [cloud region
hint](https://developers.cloudflare.com/cache/how-to/tiered-cache/#public-cloud-origins),
so this falls back to a generic topology, but it still cuts origin fetches given
the single Fly region.

This setting covers the zone. The Workers tier their own caches independently of
it — see [Caching in the Workers](#caching-in-the-workers).

## Speed settings

Both live under **Speed → Settings → Content Optimization**, both are free, and
both are off by default.

### Early Hints

`ApplicationController#preload_assets` already emits `Link: rel=preload` headers
for the stylesheet, the JS bundle and six WOFF2 faces on every HTML response.
With Early Hints on, Cloudflare caches those headers and replays them as a `103`
while the origin is still working, so the browser starts fetching a round trip
earlier. The [requirements](https://developers.cloudflare.com/cache/advanced-configuration/early-hints/)
are already met: the responses are HTML, `200`, and cacheable.

```bash
curl -sSv --http2 https://www.allencompassingtrip.com/ 2>&1 | grep 103
```

Note that a cached `103` can be emitted before an authentication check, so admin
URLs may replay their `Link` headers to anyone. Here those are digest-named
asset paths and nothing more, which is why this is a footnote rather than a
reason not to enable it.

### Speed Brain

Prefetches the likely next navigation using the [Speculation Rules
API](https://developers.cloudflare.com/speed/optimization/content/speed-brain/).
Its requirements hold for this site: entry and list pages are cache-eligible,
and they don't invoke a Worker (only `/images/*`, `/ig/*` and `/pa/*` do, and
those aren't navigations). Prefetches are served from cache or dropped — they
never reach Fly — so this adds no origin load.

```bash
curl -sSI https://www.allencompassingtrip.com/ | grep -i speculation
```

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

## Caching in the Workers

Both Workers use [Workers
Caching](https://developers.cloudflare.com/workers/cache/), turned on by a
`cache` block in their `wrangler.jsonc`. It is worth knowing that this is a
different cache from the zone's, with a different configuration surface:

- **None of the zone settings above apply to it.** Not the Cache Rules, not the
  Tiered Cache topology, not the default file-extension list. The Worker's
  response headers are the entire configuration — which is why the Workers set
  `cache-control` explicitly on every path they return, including the error
  paths. An unmarked error response would otherwise be given a freshness window
  heuristically, and a cached 404 outlives whatever caused it.
- **It is tiered, read-through and request-collapsing by default.** A photo is
  transformed once for the network rather than once per data center, and a burst
  of concurrent requests for the same URL — which is exactly what a new post
  being shared looks like — fills the cache once instead of once per request. On
  a hit the Worker doesn't run at all.
- **`cross_version_cache` is on.** Without it each deployed version caches
  separately and a deploy throws away a year of transformed images.

This replaced the Cache API (`caches.default`), which is local to one data
center and does none of the above. It's also why `Photo#warm_cache` sends a GET
rather than a HEAD: an HTTP cache won't store a HEAD response, and warming now
populates the upper tier, so it helps wherever the download comes from.

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
