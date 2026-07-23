import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import worker, { TRANSFORM_PATH, INSTAGRAM_PATH, parseOptions, negotiateFormat } from './index.js';

const match = (pattern, path) => {
  const result = pattern.exec(path);
  return result ? result.slice(1) : null;
};

describe('TRANSFORM_PATH', () => {
  it('splits options from the blob key', () => {
    expect(match(TRANSFORM_PATH, '/images/width=820,format=auto/6d1r4ctntxsl')).toEqual([
      'width=820,format=auto',
      '6d1r4ctntxsl'
    ]);
  });

  it('accepts a key with no options', () => {
    expect(match(TRANSFORM_PATH, '/images/6d1r4ctntxsl')).toEqual([undefined, '6d1r4ctntxsl']);
  });

  it('accepts a trim option, whose separators are semicolons', () => {
    expect(match(TRANSFORM_PATH, '/images/trim=200;300;200;300,width=500/abc123')).toEqual([
      'trim=200;300;200;300,width=500',
      'abc123'
    ]);
  });

  it('accepts an encoded background colour', () => {
    expect(match(TRANSFORM_PATH, '/images/width=500,fit=pad,background=%23fff/abc123')).toEqual([
      'width=500,fit=pad,background=%23fff',
      'abc123'
    ]);
  });

  it('rejects a path that walks outside the images route', () => {
    expect(match(TRANSFORM_PATH, '/images/width=100/../../etc/passwd')).toBeNull();
    expect(match(TRANSFORM_PATH, '/images/width=100/https://example.com/evil.jpg')).toBeNull();
  });
});

describe('INSTAGRAM_PATH', () => {
  it('captures both frames and the key', () => {
    expect(match(INSTAGRAM_PATH, '/ig/1440x1700/1440x1800/abc123')).toEqual([
      '1440',
      '1700',
      '1440',
      '1800',
      'abc123'
    ]);
  });

  it('rejects a malformed frame', () => {
    expect(match(INSTAGRAM_PATH, '/ig/1440/1440x1800/abc123')).toBeNull();
  });
});

describe('parseOptions', () => {
  it('returns no options for an empty string', () => {
    expect(parseOptions('')).toEqual({});
  });

  it('parses the options the app generates', () => {
    expect(parseOptions('width=820,format=auto')).toEqual({ width: 820, format: 'auto' });
    expect(parseOptions('width=500,height=300,fit=pad,background=%23fff,quality=100,format=jpeg')).toEqual({
      width: 500,
      height: 300,
      fit: 'pad',
      background: '#fff',
      quality: 100,
      format: 'jpeg'
    });
  });

  it('converts trim into the four sides cf.image expects', () => {
    expect(parseOptions('trim=200;300;200;300,width=500')).toEqual({
      trim: { top: 200, right: 300, bottom: 200, left: 300 },
      width: 500
    });
  });

  it('keeps saturation=0, which is how grayscale is expressed', () => {
    expect(parseOptions('width=300,saturation=0')).toEqual({ width: 300, saturation: 0 });
  });

  it('rejects unknown options', () => {
    expect(parseOptions('rotate=90')).toBeNull();
    expect(parseOptions('width=300,blur=100')).toBeNull();
  });

  it('rejects values outside their allowed range', () => {
    expect(parseOptions('quality=0')).toBeNull();
    expect(parseOptions('quality=101')).toBeNull();
    expect(parseOptions('width=99999')).toBeNull();
    expect(parseOptions('saturation=2')).toBeNull();
  });

  it('rejects malformed values', () => {
    expect(parseOptions('width=abc')).toBeNull();
    expect(parseOptions('fit=destroy')).toBeNull();
    expect(parseOptions('format=svg')).toBeNull();
    expect(parseOptions('background=javascript:alert(1)')).toBeNull();
    expect(parseOptions('trim=200;300')).toBeNull();
  });
});

describe('negotiateFormat', () => {
  const accepting = (accept) => new Request('https://example.com/images/abc', { headers: { Accept: accept } });

  it('prefers avif, then webp, then jpeg', () => {
    expect(negotiateFormat(accepting('image/avif,image/webp,*/*'))).toBe('avif');
    expect(negotiateFormat(accepting('image/webp,*/*'))).toBe('webp');
    expect(negotiateFormat(accepting('*/*'))).toBe('jpeg');
  });

  it('falls back to jpeg when the header is missing', () => {
    expect(negotiateFormat(new Request('https://example.com/images/abc'))).toBe('jpeg');
  });
});

// The Worker no longer touches the Cache API — Workers Caching reads through
// before it runs (see the `cache` block in wrangler.jsonc) — so what it says
// about caching is entirely in the headers it returns, and testable here.
describe('fetch', () => {
  const env = { IMAGES_ORIGIN_HOST: 'photos.example.com' };

  const upstream = (body, init) => {
    global.fetch = vi.fn(async (url, options) => {
      calls.push({ url, options });
      return new Response(body, init);
    });
  };

  let calls;
  beforeEach(() => {
    calls = [];
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  const get = (path, headers) =>
    worker.fetch(new Request(`https://example.com${path}`, { headers }), env);

  it('resolves the key against the bucket and pins the result for a year', async () => {
    upstream('jpeg bytes', { status: 200 });
    const response = await get('/images/width=608/6d1r4ctntxsl');

    expect(calls[0].url).toBe('https://photos.example.com/6d1r4ctntxsl');
    expect(calls[0].options.cf.image).toEqual({ width: 608 });
    expect(response.headers.get('cache-control')).toBe('public, max-age=31536000, immutable');
  });

  // format=auto is answered from Accept, so the cached copy has to say it varies —
  // otherwise the first browser to ask picks the format everyone else gets.
  it('varies on Accept when it negotiated the format', async () => {
    upstream('avif bytes', { status: 200 });
    const response = await get('/images/width=608,format=auto/6d1r4ctntxsl', {
      Accept: 'image/avif,image/webp,*/*'
    });

    expect(calls[0].options.cf.image.format).toBe('avif');
    expect(response.headers.get('vary')).toBe('Accept');
  });

  // An explicit format is the same answer for every browser. Saying it varies would
  // split its cache entry across Accept headers for nothing.
  it('does not vary when the format was asked for outright', async () => {
    upstream('jpeg bytes', { status: 200 });
    const response = await get('/images/width=608,format=jpeg/6d1r4ctntxsl', {
      Accept: 'image/avif,image/webp,*/*'
    });

    expect(calls[0].options.cf.image.format).toBe('jpeg');
    expect(response.headers.get('vary')).toBeNull();
  });

  it('drops cookies, which would make the response uncacheable', async () => {
    upstream('jpeg bytes', { status: 200, headers: { 'Set-Cookie': 'a=b' } });
    const response = await get('/images/width=608/6d1r4ctntxsl');

    expect(response.headers.get('set-cookie')).toBeNull();
  });

  // Nothing below is allowed into the cache: with a read-through cache in front,
  // an unmarked error would be given a freshness window heuristically.
  it('refuses to cache a missing image', async () => {
    upstream('nope', { status: 404 });
    const response = await get('/images/width=608/6d1r4ctntxsl');

    expect(response.status).toBe(404);
    expect(response.headers.get('cache-control')).toBe('no-store');
  });

  it('refuses to cache a rejected option', async () => {
    upstream('unused', { status: 200 });
    const response = await get('/images/width=608,fit=destroy/6d1r4ctntxsl');

    expect(response.status).toBe(400);
    expect(response.headers.get('cache-control')).toBe('no-store');
    expect(calls).toHaveLength(0);
  });

  it('refuses to cache an instagram frame outside the allowed bounds', async () => {
    upstream('unused', { status: 200 });
    const response = await get('/ig/1440x9999/1440x1800/6d1r4ctntxsl');

    expect(response.status).toBe(400);
    expect(response.headers.get('cache-control')).toBe('no-store');
  });

  it('refuses to cache an unrecognised path', async () => {
    const response = await get('/images/../etc/passwd');

    expect(response.status).toBe(404);
    expect(response.headers.get('cache-control')).toBe('no-store');
  });

  it('refuses to cache a transform that blew up', async () => {
    global.fetch = vi.fn(async () => {
      throw new Error('R2 unreachable');
    });
    vi.spyOn(console, 'log').mockImplementation(() => {});

    const response = await get('/images/width=608/6d1r4ctntxsl');

    expect(response.status).toBe(502);
    expect(response.headers.get('cache-control')).toBe('no-store');
  });
});
