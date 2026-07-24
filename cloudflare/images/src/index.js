// Serves every image on the site, so the R2 bucket's hostname never appears in
// a public URL. Three shapes:
//
//   /images/<options>/<key>   a single transform, e.g. width=800,format=auto
//   /images/<key>             the original, untransformed
//   /ig/<innerWxH>/<outerWxH>/<key>   the Instagram feed variant
//
// Regular transforms run through `cf.image` on the fetch to R2, which is the
// same engine behind /cdn-cgi/image/ URLs. The Instagram variant pads twice —
// onto an inset inner frame, then onto the outer frame — so the photo is matted
// with white on all four sides, the way it looked under Thumbor. That needs the
// Images binding, because `cf.image` applies one transform per fetch and
// transform URLs can't be chained: a /cdn-cgi/image/ URL isn't fetchable as
// another transform's source, and fails with "ERROR 9404".
//
// Rails builds these URLs; see app/models/concerns/thumborizable.rb.
//
// Caching is declarative: the `cache` block in wrangler.jsonc turns on Workers
// Caching, which reads through before this code runs, collapses concurrent
// requests for the same URL into one, and is tiered — so a photo is transformed
// once for the whole network rather than once per data center. All this file
// does is say what may be cached, in `cacheable` and `error` below.
//
// Every distinct set of options is a separately billed Images transformation, and
// every distinct URL is its own cache entry, so `parseOptions` is deliberately
// strict about spellings that would render identically: no duplicate names, no
// trailing junk, no leading zeros. See cloudflare/README.md.

export const TRANSFORM_PATH = /^\/images\/(?:([^/]*=[^/]*)\/)?([A-Za-z0-9_-]+)$/;
export const INSTAGRAM_PATH = /^\/ig\/(\d{1,4})x(\d{1,4})\/(\d{1,4})x(\d{1,4})\/([A-Za-z0-9_-]+)$/;

// The largest output the app ever asks for is 4000 (see Photo#bluesky_url); srcset
// tops out at 3360 (config/photos.yml).
const MAX_OUTPUT_DIMENSION = 4096;
// Trim offsets are measured in *source* pixels, so they have to allow for an original
// larger than any output — bounded by the largest input Cloudflare will transform.
const MAX_SOURCE_DIMENSION = 12000;
// `env.IMAGES.input()` caps at 20 MB, well under the 100 MB `cf.image` accepts, so
// the /ig/ route can fail on an original the /images/ route handles fine.
const MAX_INPUT_BYTES = 20 * 1024 * 1024;
const INSTAGRAM_BACKGROUND = '#ffffff';
const INSTAGRAM_QUALITY = 100;
const MAX_AGE = 31536000; // 1 year; a photo's key changes when the photo does
const CACHE_TAG = 'images';

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // Workers Caching only stores GET and HEAD anyway; without this, a POST was
    // answered with a fresh GET to the bucket.
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return error('Method not allowed', 405, { allow: 'GET, HEAD' });
    }

    try {
      const instagram = INSTAGRAM_PATH.exec(url.pathname);
      if (instagram) return await serveInstagram(instagram, env);

      const transform = TRANSFORM_PATH.exec(url.pathname);
      if (transform) return await serveTransform(transform, request, env);

      return error('Not found', 404);
    } catch (failure) {
      console.log(JSON.stringify({
        message: 'Image request failed',
        pathname: url.pathname,
        ...describe(failure)
      }));
      return error('Could not render image', 502);
    }
  }
};

async function serveTransform([, rawOptions, key], request, env) {
  const options = parseOptions(rawOptions ?? '');
  if (!options) return error('Unsupported options', 400);

  // `auto` isn't a format cf.image understands, so negotiate it here. The
  // response then varies on Accept, otherwise the first browser to ask would
  // pick the format everyone else gets. Only when we actually negotiated: an
  // explicit `format=jpeg` is the same answer for every browser, and saying it
  // varies would split its cache entry for nothing.
  const negotiated = options.format === 'auto';
  if (negotiated) options.format = negotiateFormat(request);

  const response = await fetch(sourceUrl(env, key), { cf: { image: options } });
  if (!response.ok) return upstreamError(response, key, options);

  return cacheable(response, key, negotiated);
}

async function serveInstagram([, innerWidth, innerHeight, outerWidth, outerHeight, key], env) {
  const inner = { width: Number(innerWidth), height: Number(innerHeight) };
  const outer = { width: Number(outerWidth), height: Number(outerHeight) };

  if ([inner, outer].some((frame) => !withinBounds(frame.width) || !withinBounds(frame.height))) {
    return error('Unsupported dimensions', 400);
  }

  const original = await fetch(sourceUrl(env, key));
  if (!original.ok) return upstreamError(original, key, { inner, outer });

  // Checked up front so an oversized original is a 413 that says why, rather than
  // the binding throwing and surfacing as an indistinguishable 502.
  const bytes = Number(original.headers.get('content-length'));
  if (bytes > MAX_INPUT_BYTES) {
    console.log(JSON.stringify({
      message: 'Original too large for the Images binding',
      key,
      bytes,
      limit: MAX_INPUT_BYTES
    }));
    return error('Image too large to render', 413);
  }

  const result = await env.IMAGES.input(original.body)
    .transform({ ...inner, fit: 'pad', background: INSTAGRAM_BACKGROUND })
    .transform({ ...outer, fit: 'pad', background: INSTAGRAM_BACKGROUND })
    .output({ format: 'image/jpeg', quality: INSTAGRAM_QUALITY });

  return cacheable(result.response(), key);
}

function sourceUrl(env, key) {
  return `https://${env.IMAGES_ORIGIN_HOST}/${key}`;
}

const FITS = ['pad', 'cover', 'contain', 'crop', 'scale-down', 'aspect-crop'];
const FORMATS = ['auto', 'jpeg', 'webp', 'avif'];

const OPTIONS = {
  width: (value) => size(value),
  height: (value) => size(value),
  quality: (value) => bounded(value, 1, 100),
  saturation: (value) => (value === '0' ? 0 : undefined),
  fit: (value) => (FITS.includes(value) ? value : undefined),
  format: (value) => (FORMATS.includes(value) ? value : undefined),
  // Rails writes this as `background=%23fff`; a literal `#` would start the URL
  // fragment and never reach us. Decoding with decodeURIComponent would throw on a
  // malformed escape (`background=%`), which escaped parseOptions and came back as a
  // 502 instead of a 400 — and no other encoding was ever valid here anyway.
  background: (value) => {
    const color = (value ?? '').replace(/^%23/i, '#');
    return /^#([0-9a-f]{3}|[0-9a-f]{6})$/i.test(color) ? color : undefined;
  },
  // `trim=top;right;bottom;left`, in pixels shaved off each side.
  trim: (value) => {
    const sides = (value ?? '').split(';');
    if (sides.length !== 4) return undefined;

    const [top, right, bottom, left] = sides.map(offset);
    if ([top, right, bottom, left].some((side) => side === undefined)) return undefined;

    return { top, right, bottom, left };
  }
};

// Every option the app asks for is allowlisted explicitly, so the route can't
// be used to run arbitrary transformations against the bucket.
export function parseOptions(raw) {
  if (raw === '') return {};

  const options = {};

  for (const pair of raw.split(',')) {
    const separator = pair.indexOf('=');
    if (separator === -1) return null;

    const name = pair.slice(0, separator);
    const value = pair.slice(separator + 1);

    // A second `=` used to be dropped silently, so `background=%23fff=junk` parsed as
    // `#fff`: a distinct URL, and a distinct cache entry, for identical output.
    if (value.includes('=')) return null;

    // hasOwn, not `OPTIONS[name]` — that inherited every key on Object.prototype, so
    // `toString=x` and `constructor=x` walked straight past the allowlist and were
    // handed to cf.image.
    if (!Object.hasOwn(OPTIONS, name)) return null;

    // Same reasoning as the trailing junk above: `width=100,width=200` used to render
    // as `width=200` under its own cache key.
    if (Object.hasOwn(options, name)) return null;

    const parsed = OPTIONS[name](value);
    if (parsed === undefined) return null;

    options[name] = parsed;
  }

  return options;
}

// An output dimension. Zero is not one — it used to be accepted here because this
// bound was shared with the trim sides below, and cf.image's rejection of it came
// back as "Image not found".
export function size(value) {
  return bounded(value, 1, MAX_OUTPUT_DIMENSION);
}

// A trim offset, in source pixels, where zero means "shave nothing off this side".
export function offset(value) {
  return bounded(value, 0, MAX_SOURCE_DIMENSION);
}

export function bounded(value, min, max) {
  // No leading zeros: `width=0608` renders exactly like `width=608` but caches and
  // bills as its own transformation.
  if (!/^(0|[1-9]\d{0,4})$/.test(value ?? '')) return undefined;
  const number = Number(value);
  return number >= min && number <= max ? number : undefined;
}

function withinBounds(value) {
  return Number.isInteger(value) && value >= 1 && value <= MAX_OUTPUT_DIMENSION;
}

export function negotiateFormat(request) {
  const accept = request.headers.get('Accept') ?? '';
  if (accept.includes('image/avif')) return 'avif';
  if (accept.includes('image/webp')) return 'webp';
  return 'jpeg';
}

function cacheable(upstream, key, negotiated = false) {
  const response = new Response(upstream.body, upstream);
  response.headers.set('cache-control', `public, max-age=${MAX_AGE}, immutable`);
  // Nothing served here is a document, and the content-type is whatever was set on
  // the blob at upload time, so don't let a browser sniff its way to something else.
  response.headers.set('x-content-type-options', 'nosniff');
  // The only handle on this cache: `cross_version_cache` means a deploy doesn't clear
  // it, and a year of `immutable` means nothing lapses on its own. Every variant of a
  // key gets the same tags, because a purge invalidates them together.
  response.headers.set('cache-tag', `${CACHE_TAG},${CACHE_TAG}-${key}`);
  // A response carrying cookies is never cached, and R2 has no business setting
  // one on an image anyway.
  response.headers.delete('set-cookie');
  if (negotiated) response.headers.set('vary', 'Accept');
  return response;
}

// A 404 from the bucket is the photo genuinely not being there. Anything else is
// either a transient failure — which used to be reported as a permanent absence — or
// a set of options that passed the allowlist and Image Resizing rejected anyway.
function upstreamError(response, key, options) {
  if (response.status === 404) return error('Image not found', 404);

  console.log(JSON.stringify({
    message: 'Image upstream failed',
    key,
    options,
    status: response.status
  }));

  return response.status >= 500
    ? error('Could not render image', 502)
    : error('Could not render image', 400);
}

// Errors say so explicitly. Without a cache-control header the cache in front of
// this Worker is free to pick a freshness window heuristically, and a 404 that
// outlives whatever caused it is far worse than one we serve twice.
function error(message, status, headers = {}) {
  return new Response(message, {
    status,
    headers: { 'cache-control': 'no-store', ...headers }
  });
}

// Anything can be thrown, and `.message` on a thrown string is undefined — which is
// what the log used to record.
function describe(failure) {
  return failure instanceof Error
    ? { error: failure.message, stack: failure.stack }
    : { error: String(failure) };
}
