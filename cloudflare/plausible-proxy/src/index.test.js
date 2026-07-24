// Runs in the `workers` project (node environment, see vitest.config.js). Under jsdom these
// header assertions would pass vacuously: jsdom's Request drops the method and headers of a
// Request passed as init, which is exactly how the Worker builds its upstream request.
import { describe, it, expect, afterEach, beforeEach, vi } from 'vitest';
import worker from './index.js';

// Several tests below spy on console.log and assert on what was logged, which only
// works if the spy doesn't carry calls over from the previous test.
afterEach(() => {
  vi.restoreAllMocks();
});

// Caching is Workers Caching now (see the `cache` block in wrangler.jsonc), so there is no
// cache to stub: what the Worker stores is decided entirely by the cache-control header it
// returns, which is what these tests assert on.
const env = { PLAUSIBLE_SCRIPT_URL: 'https://plausible.io/js/pa-test.js' };

describe('/pa/event', () => {
  let forwarded;

  beforeEach(() => {
    forwarded = undefined;
    global.fetch = vi.fn(async (request) => {
      forwarded = request;
      return new Response(null, { status: 202 });
    });
  });

  const post = (headers) =>
    worker.fetch(
      new Request('https://example.com/pa/event', {
        method: 'POST',
        headers,
        body: '{"n":"pageview"}'
      }),
      env
    );

  it('forwards to the Plausible event API', async () => {
    await post({ 'CF-Connecting-IP': '203.0.113.7' });
    expect(forwarded.url).toBe('https://plausible.io/api/event');
    expect(forwarded.method).toBe('POST');
  });

  // Plausible reads the visitor IP from X-Plausible-IP first, so that's the one we set —
  // see the README. Everything else in the chain can be rewritten by a proxy.
  it('sends the visitor IP in the header Plausible reads first', async () => {
    await post({ 'CF-Connecting-IP': '203.0.113.7' });
    expect(forwarded.headers.get('x-plausible-ip')).toBe('203.0.113.7');
    expect(forwarded.headers.get('x-forwarded-for')).toBe('203.0.113.7');
  });

  it('overwrites a visitor-supplied IP header', async () => {
    await post({ 'CF-Connecting-IP': '203.0.113.7', 'X-Plausible-IP': '8.8.8.8', 'X-Forwarded-For': '8.8.8.8' });
    expect(forwarded.headers.get('x-plausible-ip')).toBe('203.0.113.7');
    expect(forwarded.headers.get('x-forwarded-for')).toBe('203.0.113.7');
  });

  // Without CF-Connecting-IP there's nothing to overwrite with, so the forged value has to be
  // dropped rather than passed through — it outranks every other IP header Plausible checks.
  it('drops a visitor-supplied IP header when there is no real IP to replace it', async () => {
    await post({ 'X-Plausible-IP': '8.8.8.8' });
    expect(forwarded.headers.get('x-plausible-ip')).toBeNull();
  });

  // X-Plausible-IP was deleted unconditionally, but the other two were only overwritten —
  // so with no CF-Connecting-IP they survived as a forged visitor IP. B-Forwarded-For
  // outranks X-Forwarded-For in the order Plausible reads.
  it('drops every IP header a client can set, not just the first one', async () => {
    await post({
      'X-Plausible-IP': '8.8.8.8',
      'B-Forwarded-For': '8.8.8.8',
      'X-Forwarded-For': '8.8.8.8'
    });
    expect(forwarded.headers.get('x-plausible-ip')).toBeNull();
    expect(forwarded.headers.get('b-forwarded-for')).toBeNull();
    expect(forwarded.headers.get('x-forwarded-for')).toBeNull();
  });

  it('does not let a forged B-Forwarded-For outrank the real IP', async () => {
    await post({ 'CF-Connecting-IP': '203.0.113.7', 'B-Forwarded-For': '8.8.8.8' });
    expect(forwarded.headers.get('b-forwarded-for')).toBeNull();
    expect(forwarded.headers.get('x-plausible-ip')).toBe('203.0.113.7');
  });

  it('strips cookies but keeps the content type', async () => {
    await post({ 'CF-Connecting-IP': '203.0.113.7', Cookie: 'session=secret', 'Content-Type': 'application/json' });
    expect(forwarded.headers.get('cookie')).toBeNull();
    expect(forwarded.headers.get('content-type')).toBe('application/json');
  });

  // Plausible sends no cache-control of its own, and Workers Caching gives an unmarked
  // response a heuristic freshness window. This was the one path here that didn't say.
  it('says the forwarded response may not be cached', async () => {
    const response = await post({ 'CF-Connecting-IP': '203.0.113.7' });
    expect(response.headers.get('cache-control')).toBe('no-store');
  });

  it('swallows an upstream failure — a dropped event beats a failed request', async () => {
    global.fetch = vi.fn(async () => {
      throw new Error('upstream down');
    });
    vi.spyOn(console, 'log').mockImplementation(() => {});
    const response = await post({ 'CF-Connecting-IP': '203.0.113.7' });
    expect(response.status).toBe(202);
  });

  it('only forwards POSTs', async () => {
    const response = await worker.fetch(new Request('https://example.com/pa/event'), env);
    expect(response.status).toBe(405);
    expect(response.headers.get('allow')).toBe('POST');
    expect(response.headers.get('cache-control')).toBe('no-store');
    expect(forwarded).toBeUndefined();
  });
});

describe('/pa/script.js', () => {
  const get = async (upstream) => {
    global.fetch = vi.fn(async () => upstream());
    return worker.fetch(new Request('https://example.com/pa/script.js'), env);
  };

  it('serves the script and lets the edge cache it', async () => {
    const response = await get(() => new Response('window.plausible=1', { status: 200 }));
    expect(response.status).toBe(200);
    expect(response.headers.get('cache-control')).toBe('public, max-age=21600');
  });

  // A stale script URL 404s. Caching that for six hours would leave every visitor with a
  // broken script long after the URL is fixed. The failure is passed through rather than
  // hidden behind the empty script below: a script tag that 404s doesn't break the page
  // either, and it's visible instead of silent.
  it('never pins a failed fetch', async () => {
    vi.spyOn(console, 'log').mockImplementation(() => {});
    const response = await get(() => new Response('Not found', { status: 404 }));
    expect(response.status).toBe(404);
    expect(response.headers.get('cache-control')).toBe('no-store');
  });

  it('logs a failed fetch, so a stale script URL is not silent', async () => {
    const log = vi.spyOn(console, 'log').mockImplementation(() => {});
    await get(() => new Response('Not found', { status: 404 }));
    expect(log).toHaveBeenCalledOnce();
    expect(JSON.parse(log.mock.calls[0][0])).toMatchObject({
      message: 'Plausible script fetch failed',
      status: 404
    });
  });

  it('drops cookies, which the edge cache refuses to store', async () => {
    const response = await get(
      () => new Response('window.plausible=1', { status: 200, headers: { 'Set-Cookie': 'a=b' } })
    );
    expect(response.headers.get('set-cookie')).toBeNull();
  });

  it('falls back to an empty script so the page never breaks', async () => {
    vi.spyOn(console, 'log').mockImplementation(() => {});
    const response = await get(() => {
      throw new Error('upstream down');
    });
    expect(response.status).toBe(200);
    expect(response.headers.get('content-type')).toBe('application/javascript');
    expect(await response.text()).toBe('');
  });

  // The fallback above is the one response that must never be stored: six hours of a
  // cached empty script is six hours of analytics going nowhere.
  it('never lets the empty fallback be cached', async () => {
    vi.spyOn(console, 'log').mockImplementation(() => {});
    const response = await get(() => {
      throw new Error('upstream down');
    });
    expect(response.headers.get('cache-control')).toBe('no-store');
  });

  it('logs what was thrown, including a value that is not an Error', async () => {
    const log = vi.spyOn(console, 'log').mockImplementation(() => {});
    await get(() => {
      throw 'just a string';
    });
    expect(JSON.parse(log.mock.calls[0][0])).toMatchObject({
      message: 'Plausible proxy error',
      error: 'just a string'
    });
  });

  it('only serves GET and HEAD', async () => {
    global.fetch = vi.fn(async () => new Response('window.plausible=1', { status: 200 }));
    const response = await worker.fetch(
      new Request('https://example.com/pa/script.js', { method: 'POST' }),
      env
    );
    expect(response.status).toBe(405);
    expect(response.headers.get('allow')).toBe('GET, HEAD');
    expect(global.fetch).not.toHaveBeenCalled();
  });
});

describe('other paths', () => {
  it('are not proxied', async () => {
    const response = await worker.fetch(new Request('https://example.com/pa/anything'), env);
    expect(response.status).toBe(404);
    expect(response.headers.get('cache-control')).toBe('no-store');
  });
});
