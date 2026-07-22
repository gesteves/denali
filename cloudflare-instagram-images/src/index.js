// Renders the Instagram feed variant of a photo.
//
//   /ig/<innerW>x<innerH>/<outerW>x<outerH>/<key>
//
// The photo is padded onto the inner frame, and that result is padded onto the
// outer frame. Because the inner frame is inset, the photo ends up matted with
// white on all four sides — which is how these images looked under Thumbor.
//
// This can't be done with Cloudflare's URL transformations: they can't be
// chained, since a /cdn-cgi/image/ URL isn't fetchable as another transform's
// source (it fails with "ERROR 9404: Could not fetch the image"), and the
// `border` option is Workers-only. The Images binding does chain, so the
// framing happens here instead. Rails supplies both frames; see
// Photo#instagram_url.

const PATH = /^\/ig\/(\d{1,4})x(\d{1,4})\/(\d{1,4})x(\d{1,4})\/([A-Za-z0-9_-]+)$/;
const MAX_DIMENSION = 4096;
const BACKGROUND = '#ffffff';
const QUALITY = 100;
const MAX_AGE = 31536000; // 1 year; the key changes when the photo does

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const match = PATH.exec(url.pathname);

    if (!match) {
      return new Response('Not found', { status: 404 });
    }

    const [, innerWidth, innerHeight, outerWidth, outerHeight, key] = match;
    const inner = { width: Number(innerWidth), height: Number(innerHeight) };
    const outer = { width: Number(outerWidth), height: Number(outerHeight) };

    if ([inner, outer].some((f) => f.width < 1 || f.height < 1 || f.width > MAX_DIMENSION || f.height > MAX_DIMENSION)) {
      return new Response('Unsupported dimensions', { status: 400 });
    }

    // Always cache under a GET, so the HEAD requests Photo#warm_cache sends
    // populate the cache that Instagram's GET will hit.
    const cacheKey = new Request(url.toString(), { method: 'GET' });
    const cache = caches.default;

    const cached = await cache.match(cacheKey);
    if (cached) return cached;

    try {
      const original = await fetch(`https://${env.IMAGES_ORIGIN_HOST}/${key}`);
      if (!original.ok) {
        return new Response('Source image not found', { status: 404 });
      }

      const result = await env.IMAGES.input(original.body)
        .transform({ ...inner, fit: 'pad', background: BACKGROUND })
        .transform({ ...outer, fit: 'pad', background: BACKGROUND })
        .output({ format: 'image/jpeg', quality: QUALITY });

      const transformed = result.response();
      const response = new Response(transformed.body, transformed);
      response.headers.set('cache-control', `public, max-age=${MAX_AGE}, immutable`);

      ctx.waitUntil(cache.put(cacheKey, response.clone()));
      return response;
    } catch (error) {
      console.log(JSON.stringify({
        message: 'Instagram image transform failed',
        pathname: url.pathname,
        error: error.message
      }));
      return new Response('Could not transform image', { status: 502 });
    }
  }
};
