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

export const TRANSFORM_PATH = /^\/images\/(?:([^/]*=[^/]*)\/)?([A-Za-z0-9_-]+)$/;
export const INSTAGRAM_PATH = /^\/ig\/(\d{1,4})x(\d{1,4})\/(\d{1,4})x(\d{1,4})\/([A-Za-z0-9_-]+)$/;

const MAX_DIMENSION = 4096;
const INSTAGRAM_BACKGROUND = '#ffffff';
const INSTAGRAM_QUALITY = 100;
const MAX_AGE = 31536000; // 1 year; a photo's key changes when the photo does

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    try {
      const instagram = INSTAGRAM_PATH.exec(url.pathname);
      if (instagram) return await serveInstagram(instagram, request, env, ctx);

      const transform = TRANSFORM_PATH.exec(url.pathname);
      if (transform) return await serveTransform(transform, request, env, ctx);

      return new Response('Not found', { status: 404 });
    } catch (error) {
      console.log(JSON.stringify({
        message: 'Image request failed',
        pathname: url.pathname,
        error: error.message
      }));
      return new Response('Could not render image', { status: 502 });
    }
  }
};

async function serveTransform([, rawOptions, key], request, env, ctx) {
  const options = parseOptions(rawOptions ?? '');
  if (!options) return new Response('Unsupported options', { status: 400 });

  // `auto` isn't a format cf.image understands, so negotiate it here. The
  // chosen format goes into the cache key, otherwise the first browser to ask
  // would pick the format everyone else gets.
  if (options.format === 'auto') {
    options.format = negotiateFormat(request);
  }

  const cached = await matchCache(request, options.format);
  if (cached) return cached;

  const response = await fetch(sourceUrl(env, key), { cf: { image: options } });
  if (!response.ok) return new Response('Image not found', { status: 404 });

  return cacheAndReturn(response, request, ctx, options.format);
}

async function serveInstagram([, innerWidth, innerHeight, outerWidth, outerHeight, key], request, env, ctx) {
  const inner = { width: Number(innerWidth), height: Number(innerHeight) };
  const outer = { width: Number(outerWidth), height: Number(outerHeight) };

  if ([inner, outer].some((frame) => !withinBounds(frame.width) || !withinBounds(frame.height))) {
    return new Response('Unsupported dimensions', { status: 400 });
  }

  const cached = await matchCache(request);
  if (cached) return cached;

  const original = await fetch(sourceUrl(env, key));
  if (!original.ok) return new Response('Image not found', { status: 404 });

  const result = await env.IMAGES.input(original.body)
    .transform({ ...inner, fit: 'pad', background: INSTAGRAM_BACKGROUND })
    .transform({ ...outer, fit: 'pad', background: INSTAGRAM_BACKGROUND })
    .output({ format: 'image/jpeg', quality: INSTAGRAM_QUALITY });

  return cacheAndReturn(result.response(), request, ctx);
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

// Cache under a GET, so the HEAD requests Photo#warm_cache sends populate the
// cache that the eventual GET will hit.
function cacheKey(request, format) {
  const url = new URL(request.url);
  if (format) url.searchParams.set('format', format);
  return new Request(url.toString(), { method: 'GET' });
}

function matchCache(request, format) {
  return caches.default.match(cacheKey(request, format));
}

function cacheAndReturn(upstream, request, ctx, format) {
  const response = new Response(upstream.body, upstream);
  response.headers.set('cache-control', `public, max-age=${MAX_AGE}, immutable`);
  response.headers.delete('set-cookie');
  if (format) response.headers.set('vary', 'Accept');

  ctx.waitUntil(caches.default.put(cacheKey(request, format), response.clone()));
  return response;
}
