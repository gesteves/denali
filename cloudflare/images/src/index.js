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

export const TRANSFORM_PATH = /^\/images\/(?:([^/]*=[^/]*)\/)?([A-Za-z0-9_-]+)$/;
export const INSTAGRAM_PATH = /^\/ig\/(\d{1,4})x(\d{1,4})\/(\d{1,4})x(\d{1,4})\/([A-Za-z0-9_-]+)$/;

const MAX_DIMENSION = 4096;
const INSTAGRAM_BACKGROUND = '#ffffff';
const INSTAGRAM_QUALITY = 100;
const MAX_AGE = 31536000; // 1 year; a photo's key changes when the photo does

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

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
        error: failure.message
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
  if (!response.ok) return error('Image not found', 404);

  return cacheable(response, negotiated);
}

async function serveInstagram([, innerWidth, innerHeight, outerWidth, outerHeight, key], env) {
  const inner = { width: Number(innerWidth), height: Number(innerHeight) };
  const outer = { width: Number(outerWidth), height: Number(outerHeight) };

  if ([inner, outer].some((frame) => !withinBounds(frame.width) || !withinBounds(frame.height))) {
    return error('Unsupported dimensions', 400);
  }

  const original = await fetch(sourceUrl(env, key));
  if (!original.ok) return error('Image not found', 404);

  const result = await env.IMAGES.input(original.body)
    .transform({ ...inner, fit: 'pad', background: INSTAGRAM_BACKGROUND })
    .transform({ ...outer, fit: 'pad', background: INSTAGRAM_BACKGROUND })
    .output({ format: 'image/jpeg', quality: INSTAGRAM_QUALITY });

  return cacheable(result.response());
}

function sourceUrl(env, key) {
  return `https://${env.IMAGES_ORIGIN_HOST}/${key}`;
}

const FITS = ['pad', 'cover', 'contain', 'crop', 'scale-down', 'aspect-crop'];
const FORMATS = ['auto', 'jpeg', 'webp', 'avif'];

const OPTIONS = {
  width: (value) => dimension(value),
  height: (value) => dimension(value),
  quality: (value) => bounded(value, 1, 100),
  saturation: (value) => (value === '0' ? 0 : undefined),
  fit: (value) => (FITS.includes(value) ? value : undefined),
  format: (value) => (FORMATS.includes(value) ? value : undefined),
  background: (value) => {
    const color = decodeURIComponent(value ?? '');
    return /^#([0-9a-f]{3}|[0-9a-f]{6})$/i.test(color) ? color : undefined;
  },
  // `trim=top;right;bottom;left`, in pixels shaved off each side.
  trim: (value) => {
    const sides = (value ?? '').split(';');
    if (sides.length !== 4) return undefined;

    const [top, right, bottom, left] = sides.map(dimension);
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
    const [name, value] = pair.split('=');
    const parse = OPTIONS[name];
    if (!parse) return null;

    const parsed = parse(value);
    if (parsed === undefined) return null;

    options[name] = parsed;
  }

  return options;
}

export function dimension(value) {
  return bounded(value, 0, MAX_DIMENSION * 4);
}

export function bounded(value, min, max) {
  if (!/^\d{1,5}$/.test(value ?? '')) return undefined;
  const number = Number(value);
  return number >= min && number <= max ? number : undefined;
}

function withinBounds(value) {
  return Number.isInteger(value) && value >= 1 && value <= MAX_DIMENSION;
}

export function negotiateFormat(request) {
  const accept = request.headers.get('Accept') ?? '';
  if (accept.includes('image/avif')) return 'avif';
  if (accept.includes('image/webp')) return 'webp';
  return 'jpeg';
}

function cacheable(upstream, negotiated = false) {
  const response = new Response(upstream.body, upstream);
  response.headers.set('cache-control', `public, max-age=${MAX_AGE}, immutable`);
  // A response carrying cookies is never cached, and R2 has no business setting
  // one on an image anyway.
  response.headers.delete('set-cookie');
  if (negotiated) response.headers.set('vary', 'Accept');
  return response;
}

// Errors say so explicitly. Without a cache-control header the cache in front of
// this Worker is free to pick a freshness window heuristically, and a 404 that
// outlives whatever caused it is far worse than one we serve twice.
function error(message, status) {
  return new Response(message, {
    status,
    headers: { 'cache-control': 'no-store' }
  });
}
