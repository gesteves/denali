# Images

A Cloudflare Worker that serves every image on the site. It resolves photos
against the R2 bucket internally, so the bucket's hostname never appears in a
public URL.

| Path | Result |
|------|--------|
| `/images/<options>/<key>` | The photo, transformed — e.g. `width=800,format=auto` |
| `/images/<key>` | The original, untransformed |
| `/ig/<innerWxH>/<outerWxH>/<key>` | The Instagram feed variant |

`<key>` is an ActiveStorage blob key. Rails builds all of these URLs; see
`app/models/concerns/thumborizable.rb` and `Photo#instagram_url`.

## How it works

Ordinary transforms are applied with `cf.image` on the fetch to R2 — the same
engine that backs `/cdn-cgi/image/` URLs, so the options mirror [Cloudflare's
image features](https://developers.cloudflare.com/images/optimization/features/).
Only the options the app actually uses are accepted; anything else is a `400`,
so the route can't be used to run arbitrary transformations against the bucket.

`format=auto` is resolved here rather than by Cloudflare, since `cf.image` has
no `auto`. The Worker reads the request's `Accept` header, picks AVIF, WebP or
JPEG, and answers with `Vary: Accept` so one browser's capabilities don't decide
the format everyone else is served. Only when it negotiated: an explicit
`format=jpeg` is the same answer for every browser, and claiming it varies would
split its cache entry for nothing.

`Vary` values are compared verbatim, with no normalization, so each distinct
browser `Accept` string is its own cache variant — realistically a handful of
strings mapping onto three formats. If that fragmentation ever shows up in cache
analytics, the fix is a request-phase Transform Rule on `/images/*` that
canonicalizes `Accept` before the Worker runs. Write it down here if it comes to
that.

The Instagram variant is the exception, and the reason this Worker exists at
all. It pads the photo onto an inset inner frame, then pads that result onto
the outer frame, leaving white on all four sides — the way these images looked
under Thumbor. That can't be expressed as a single transform:

- **Transforms can't be chained.** A transform URL isn't fetchable as another
  transform's source; Cloudflare's internal subrequest 404s, surfacing as
  `ERROR 9404: Could not fetch the image`.
- **`fit=pad` alone can't inset.** It scales the photo until it meets the frame
  on one axis, so it can't leave a margin on all four sides.
- **The `border` option is Workers-only**, not available on URL transforms.

So that route uses the [Images
binding](https://developers.cloudflare.com/images/optimization/binding/), which
does support chaining `.transform()` calls.

## Caching

There is no caching code in `src/index.js`. The `cache` block in
`wrangler.jsonc` turns on [Workers
Caching](https://developers.cloudflare.com/workers/cache/), which reads through
before the Worker runs, collapses concurrent requests for the same URL, and is
tiered — so a photo is transformed once for the network rather than once per
data center, and a hit doesn't run this code at all. All the Worker does is set
`cache-control`: a year and `immutable` on success, `no-store` on every error.
See [the zone README](../README.md#caching-in-the-workers) for how this relates
to the zone's own cache, which does not apply here.

## Deploying

```bash
cd cloudflare/images
npx wrangler deploy
```

Requires an Images Paid plan for the binding. Responses are cached at the edge
for a year, which is safe because ActiveStorage keys change when a photo is
replaced, so the URL changes with it.

## Local development

```bash
npx wrangler dev
```

Images binding calls don't incur usage charges in local development.

## Logs

```bash
npx wrangler tail denali-images
```
