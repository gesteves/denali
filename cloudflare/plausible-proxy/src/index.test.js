// Runs in the `workers` project (node environment, see vitest.config.js). Under jsdom these
// header assertions would pass vacuously: jsdom's Request drops the method and headers of a
// Request passed as init, which is exactly how the Worker builds its upstream request.
import { describe, it, expect, beforeEach, vi } from 'vitest';
import worker from './index.js';

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

  it('strips cookies but keeps the content type', async () => {
    await post({ 'CF-Connecting-IP': '203.0.113.7', Cookie: 'session=secret', 'Content-Type': 'application/json' });
    expect(forwarded.headers.get('cookie')).toBeNull();
    expect(forwarded.headers.get('content-type')).toBe('application/json');
  });

  it('swallows an upstream failure — a dropped event beats a failed request', async () => {
    global.fetch = vi.fn(async () => {
      throw new Error('upstream down');
    });
    const response = await post({ 'CF-Connecting-IP': '203.0.113.7' });
    expect(response.status).toBe(202);
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
  // broken script long after the URL is fixed.
  it('never pins a failed fetch', async () => {
    const response = await get(() => new Response('Not found', { status: 404 }));
    expect(response.status).toBe(404);
    expect(response.headers.get('cache-control')).toBe('no-store');
  });

  it('drops cookies, which the edge cache refuses to store', async () => {
    const response = await get(
      () => new Response('window.plausible=1', { status: 200, headers: { 'Set-Cookie': 'a=b' } })
    );
    expect(response.headers.get('set-cookie')).toBeNull();
  });

  it('falls back to an empty script so the page never breaks', async () => {
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
    const response = await get(() => {
      throw new Error('upstream down');
    });
    expect(response.headers.get('cache-control')).toBe('no-store');
  });
});

describe('other paths', () => {
  it('are not proxied', async () => {
    const response = await worker.fetch(new Request('https://example.com/pa/anything'), env);
    expect(response.status).toBe(404);
    expect(response.headers.get('cache-control')).toBe('no-store');
  });
});
