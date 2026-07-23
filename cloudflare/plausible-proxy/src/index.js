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
  async fetch(request, env) {
    const { pathname } = new URL(request.url);

    try {
      if (pathname === SCRIPT_PATH) {
        return await serveScript(env);
      }

      if (pathname === EVENT_PATH) {
        return await forwardEvent(request);
      }

      return new Response('Not found', {
        status: 404,
        headers: { 'cache-control': 'no-store' }
      });
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
          headers: {
            'content-type': 'application/javascript',
            // Emphatically not cacheable: a stored empty script is six hours of
            // analytics silently going nowhere.
            'cache-control': 'no-store'
          }
        });
      }
      return new Response(null, { status: 202, headers: { 'cache-control': 'no-store' } });
    }
  }
};

// Cached by Workers Caching (see the `cache` block in wrangler.jsonc), which
// reads through before this Worker runs. The cache-control header below is the
// whole of the caching logic.
async function serveScript(env) {
  const upstream = await fetch(env.PLAUSIBLE_SCRIPT_URL);
  const response = new Response(upstream.body, upstream);
  // A response carrying cookies is never cached.
  response.headers.delete('set-cookie');
  // Only pin a script that actually loaded: a 404 (e.g. after Plausible reissues the
  // script URL) would otherwise sit in every visitor's browser cache for six hours.
  response.headers.set(
    'cache-control',
    upstream.ok ? `public, max-age=${SCRIPT_MAX_AGE}` : 'no-store'
  );

  return response;
}

async function forwardEvent(request) {
  const forwarded = new Request(EVENT_UPSTREAM, request);
  forwarded.headers.delete('cookie');

  // Plausible derives the visitor hash and country from the client IP, which it reads
  // from (in order) X-Plausible-IP, CF-Connecting-IP, B-Forwarded-For, X-Forwarded-For.
  // Set the top-precedence header ourselves rather than leaning on the CF-Connecting-IP
  // this subrequest inherits: that one is only the real visitor while plausible.io stays
  // off Cloudflare. A cross-zone subrequest would replace it with a fixed Worker IP that
  // still outranks X-Forwarded-For, silently geolocating every visitor to one address.
  // Delete before setting, so a client-supplied value can't survive as a forged IP.
  forwarded.headers.delete('x-plausible-ip');
  const clientIp = request.headers.get('CF-Connecting-IP');
  if (clientIp) {
    forwarded.headers.set('X-Plausible-IP', clientIp);
    forwarded.headers.set('X-Forwarded-For', clientIp);
  }

  return fetch(forwarded);
}
