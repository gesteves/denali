// Serves Plausible Analytics as a first-party script and event endpoint, so
// neither is blocked by content blockers that filter requests to plausible.io.
//
//   /pa/script.js -> the site's personalized Plausible script (cached at the edge)
//   /pa/event     -> https://plausible.io/api/event
//
// The paths deliberately avoid /js/ and /api/, which the app's WAF rules block.

const SCRIPT_PATH = '/pa/script.js';
const EVENT_PATH = '/pa/event';
const EVENT_UPSTREAM = 'https://plausible.io/api/event';
const SCRIPT_MAX_AGE = 21600; // 6 hours

export default {
  async fetch(request, env, ctx) {
    const { pathname } = new URL(request.url);

    try {
      if (pathname === SCRIPT_PATH) {
        return await serveScript(request, env, ctx);
      }

      if (pathname === EVENT_PATH) {
        return await forwardEvent(request);
      }

      return new Response('Not found', { status: 404 });
    } catch (error) {
      console.log(JSON.stringify({
        message: 'Plausible proxy error',
        pathname,
        error: error.message
      }));

      // Analytics must never break the page. An empty script still parses, and
      // a dropped event is preferable to a console full of failed requests.
      if (pathname === SCRIPT_PATH) {
        return new Response('', {
          status: 200,
          headers: { 'content-type': 'application/javascript' }
        });
      }
      return new Response(null, { status: 202 });
    }
  }
};

async function serveScript(request, env, ctx) {
  const cache = caches.default;
  const cacheable = request.method === 'GET';

  if (cacheable) {
    const cached = await cache.match(request);
    if (cached) return cached;
  }

  const upstream = await fetch(env.PLAUSIBLE_SCRIPT_URL);
  const response = new Response(upstream.body, upstream);
  // cache.put rejects responses carrying cookies.
  response.headers.delete('set-cookie');
  response.headers.set('cache-control', `public, max-age=${SCRIPT_MAX_AGE}`);

  if (cacheable && upstream.ok) {
    ctx.waitUntil(cache.put(request, response.clone()));
  }

  return response;
}

async function forwardEvent(request) {
  const forwarded = new Request(EVENT_UPSTREAM, request);
  forwarded.headers.delete('cookie');

  // Plausible derives the visitor hash and country from the client IP, so pass
  // the real one along instead of letting it see Cloudflare's egress address.
  const clientIp = request.headers.get('CF-Connecting-IP');
  if (clientIp) {
    forwarded.headers.set('X-Forwarded-For', clientIp);
  }

  return fetch(forwarded);
}
