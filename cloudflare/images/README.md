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
JPEG, and includes the result in the cache key so one browser's capabilities
don't decide the format everyone else is served.

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

## Deploying

```bash
cd cloudflare/images
npx wrangler deploy
```

Requires an Images Paid plan for the binding. Responses are cached at the edge
for a year; ActiveStorage keys change when a photo is replaced, so URLs change
with it.

## Local development

```bash
npx wrangler dev
```

Images binding calls don't incur usage charges in local development.

## Logs

```bash
npx wrangler tail denali-images
```
