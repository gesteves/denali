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

// Plausible derives the visitor hash and country from the client IP, which it reads
// from (in order) X-Plausible-IP, CF-Connecting-IP, B-Forwarded-For, X-Forwarded-For.
// Every one a client can set is deleted before we set our own, so a forged value
// can't outrank the real IP — nor survive when there is no real IP to overwrite it
// with. CF-Connecting-IP isn't in the list because it isn't ours to control: this
// subrequest's copy is replaced by Cloudflare.
const CLIENT_IP_HEADERS = ['x-plausible-ip', 'b-forwarded-for', 'x-forwarded-for'];

export default {
  async fetch(request, env) {
    const { pathname } = new URL(request.url);

    try {
      if (pathname === SCRIPT_PATH) {
        if (request.method !== 'GET' && request.method !== 'HEAD') {
          return notAllowed('GET, HEAD');
        }
        return await serveScript(env);
      }

      if (pathname === EVENT_PATH) {
        if (request.method !== 'POST') return notAllowed('POST');
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
        ...describe(error)
      }));

      // Analytics must never break the page. An empty script still parses, and
      // a dropped event is preferable to a console full of failed requests.
      if (pathname === SCRIPT_PATH) return emptyScript();
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
  // The failure is passed through rather than swallowed into the empty script above —
  // a script tag that 404s doesn't break the page either, and it says so out loud in
  // every visitor's console instead of taking analytics down silently.
  response.headers.set(
    'cache-control',
    upstream.ok ? `public, max-age=${SCRIPT_MAX_AGE}` : 'no-store'
  );

  if (!upstream.ok) {
    console.log(JSON.stringify({
      message: 'Plausible script fetch failed',
      url: env.PLAUSIBLE_SCRIPT_URL,
      status: upstream.status
    }));
  }

  return response;
}

async function forwardEvent(request) {
  const forwarded = new Request(EVENT_UPSTREAM, request);
  forwarded.headers.delete('cookie');

  for (const header of CLIENT_IP_HEADERS) forwarded.headers.delete(header);

  const clientIp = request.headers.get('CF-Connecting-IP');
  if (clientIp) {
    // X-Plausible-IP is the one Plausible reads first. Setting it beats leaning on the
    // CF-Connecting-IP this subrequest inherits: that one is only the real visitor
    // while plausible.io stays off Cloudflare. A cross-zone subrequest would replace
    // it with a fixed Worker IP that still outranks X-Forwarded-For, silently
    // geolocating every visitor to one address.
    forwarded.headers.set('X-Plausible-IP', clientIp);
    forwarded.headers.set('X-Forwarded-For', clientIp);
  }

  const upstream = await fetch(forwarded);
  const response = new Response(upstream.body, upstream);
  // Plausible sends no cache-control, and Workers Caching gives an unmarked response a
  // heuristic freshness window. A POST is never cached, so this is belt and braces —
  // but every response either Worker returns says what may be cached, and this was the
  // one that didn't.
  response.headers.set('cache-control', 'no-store');
  return response;
}

// Emphatically not cacheable: a stored empty script is six hours of analytics
// silently going nowhere.
function emptyScript() {
  return new Response('', {
    status: 200,
    headers: {
      'content-type': 'application/javascript',
      'cache-control': 'no-store'
    }
  });
}

function notAllowed(allow) {
  return new Response('Method not allowed', {
    status: 405,
    headers: { allow, 'cache-control': 'no-store' }
  });
}

// Anything can be thrown, and `.message` on a thrown string is undefined — which is
// what the log used to record.
function describe(error) {
  return error instanceof Error
    ? { error: error.message, stack: error.stack }
    : { error: String(error) };
}
