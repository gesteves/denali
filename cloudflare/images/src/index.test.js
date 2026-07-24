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

  // Looking the name up with `OPTIONS[name]` inherited every key on Object.prototype,
  // so these walked past the allowlist and were handed to cf.image.
  it('rejects names inherited from Object.prototype', () => {
    expect(parseOptions('toString=x')).toBeNull();
    expect(parseOptions('constructor=x')).toBeNull();
    expect(parseOptions('valueOf=x')).toBeNull();
    expect(parseOptions('hasOwnProperty=x')).toBeNull();
    expect(parseOptions('__proto__=x')).toBeNull();
  });

  it('rejects values outside their allowed range', () => {
    expect(parseOptions('quality=0')).toBeNull();
    expect(parseOptions('quality=101')).toBeNull();
    expect(parseOptions('width=99999')).toBeNull();
    expect(parseOptions('saturation=2')).toBeNull();
  });

  // The largest output the app asks for is 4000 (Photo#bluesky_url).
  it('caps output dimensions at 4096', () => {
    expect(parseOptions('width=4096')).toEqual({ width: 4096 });
    expect(parseOptions('width=4097')).toBeNull();
    expect(parseOptions('height=8192')).toBeNull();
  });

  // Zero is a real trim offset ("shave nothing off this side") but not a real output
  // dimension. Sharing one bound between them meant cf.image rejected width=0 and the
  // Worker reported it as "Image not found".
  it('rejects a zero width or height, but not a zero trim side', () => {
    expect(parseOptions('width=0')).toBeNull();
    expect(parseOptions('height=0')).toBeNull();
    expect(parseOptions('trim=0;0;0;0')).toEqual({ trim: { top: 0, right: 0, bottom: 0, left: 0 } });
  });

  // Trim offsets are source pixels, so they have to outrun the output cap — an
  // original is routinely larger than anything rendered from it.
  it('allows trim offsets larger than an output dimension, up to the source limit', () => {
    expect(parseOptions('trim=0;6000;0;6000')).toEqual({
      trim: { top: 0, right: 6000, bottom: 0, left: 6000 }
    });
    expect(parseOptions('trim=0;20000;0;0')).toBeNull();
  });

  it('rejects malformed values', () => {
    expect(parseOptions('width=abc')).toBeNull();
    expect(parseOptions('fit=destroy')).toBeNull();
    expect(parseOptions('format=svg')).toBeNull();
    expect(parseOptions('background=javascript:alert(1)')).toBeNull();
    expect(parseOptions('trim=200;300')).toBeNull();
  });

  // decodeURIComponent used to throw here, which escaped parseOptions entirely and
  // came back as a 502 rather than a 400.
  it('rejects a malformed percent-escape instead of throwing', () => {
    expect(() => parseOptions('background=%')).not.toThrow();
    expect(parseOptions('background=%')).toBeNull();
    expect(parseOptions('background=%2')).toBeNull();
    expect(parseOptions('background=%zz')).toBeNull();
  });

  it('rejects an option with no value at all', () => {
    expect(parseOptions('width')).toBeNull();
    expect(parseOptions('width=608,fit')).toBeNull();
    expect(parseOptions('width=')).toBeNull();
  });

  // Every spelling below renders identically to one the app generates, but is its own
  // cache entry and its own billable transformation.
  describe('spellings that render identically to a canonical one', () => {
    it('rejects trailing junk after a second =', () => {
      expect(parseOptions('background=%23fff=junk')).toBeNull();
      expect(parseOptions('width=608=608')).toBeNull();
    });

    it('rejects a repeated option name', () => {
      expect(parseOptions('width=100,width=200')).toBeNull();
      expect(parseOptions('width=608,format=jpeg,width=608')).toBeNull();
    });

    it('rejects leading zeros', () => {
      expect(parseOptions('width=0608')).toBeNull();
      expect(parseOptions('quality=080')).toBeNull();
      expect(parseOptions('trim=00;0;0;0')).toBeNull();
    });
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
  let calls;
  let transforms;

  // Stands in for env.IMAGES, recording the chain the /ig/ route builds.
  const imagesBinding = {
    input() {
      const chain = {
        transform(options) {
          transforms.push(options);
          return chain;
        },
        output(options) {
          transforms.push(options);
          return {
            response: () =>
              new Response('matted jpeg bytes', { headers: { 'content-type': 'image/jpeg' } })
          };
        }
      };
      return chain;
    }
  };

  const env = { IMAGES_ORIGIN_HOST: 'photos.example.com', IMAGES: imagesBinding };

  const upstream = (body, init) => {
    global.fetch = vi.fn(async (url, options) => {
      calls.push({ url, options });
      return new Response(body, init);
    });
  };

  beforeEach(() => {
    calls = [];
    transforms = [];
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

  // The bucket's content-type is whatever was set at upload time, and this route serves
  // it under the site's own origin.
  it('forbids content-type sniffing', async () => {
    upstream('jpeg bytes', { status: 200 });
    const response = await get('/images/width=608/6d1r4ctntxsl');

    expect(response.headers.get('x-content-type-options')).toBe('nosniff');
  });

  // cross_version_cache means a deploy doesn't clear this cache and `immutable` means
  // nothing lapses on its own, so the tag is the only way to roll out a change to the
  // transform logic. Every variant of a key must carry the same tags.
  it('tags responses so the cache can be purged', async () => {
    upstream('jpeg bytes', { status: 200 });
    const plain = await get('/images/width=608/6d1r4ctntxsl');
    expect(plain.headers.get('cache-tag')).toBe('images,images-6d1r4ctntxsl');

    const negotiated = await get('/images/width=608,format=auto/6d1r4ctntxsl', {
      Accept: 'image/avif,*/*'
    });
    expect(negotiated.headers.get('cache-tag')).toBe('images,images-6d1r4ctntxsl');
  });

  // Nothing below is allowed into the cache: with a read-through cache in front,
  // an unmarked error would be given a freshness window heuristically.
  it('refuses to cache a missing image', async () => {
    upstream('nope', { status: 404 });
    const response = await get('/images/width=608/6d1r4ctntxsl');

    expect(response.status).toBe(404);
    expect(response.headers.get('cache-control')).toBe('no-store');
  });

  // A 5xx from the bucket used to be reported as a 404 — a transient failure dressed up
  // as a permanent absence.
  it('reports an upstream failure as a failure, not as a missing image', async () => {
    vi.spyOn(console, 'log').mockImplementation(() => {});
    upstream('upstream is unwell', { status: 503 });
    const response = await get('/images/width=608/6d1r4ctntxsl');

    expect(response.status).toBe(502);
    expect(response.headers.get('cache-control')).toBe('no-store');
  });

  // Options that passed the allowlist and Image Resizing rejected anyway are a bug in
  // the allowlist, not a missing photo.
  it('reports a rejected transform as a bad request', async () => {
    vi.spyOn(console, 'log').mockImplementation(() => {});
    upstream('bad params', { status: 400 });
    const response = await get('/images/width=608/6d1r4ctntxsl');

    expect(response.status).toBe(400);
    expect(response.headers.get('cache-control')).toBe('no-store');
  });

  it('refuses to cache a rejected option', async () => {
    upstream('unused', { status: 200 });
    const response = await get('/images/width=608,fit=destroy/6d1r4ctntxsl');

    expect(response.status).toBe(400);
    expect(response.headers.get('cache-control')).toBe('no-store');
    expect(calls).toHaveLength(0);
  });

  // This used to throw inside decodeURIComponent and come back as a 502.
  it('answers a malformed option with a bad request, not a bad gateway', async () => {
    upstream('unused', { status: 200 });
    const response = await get('/images/width=608,background=%/6d1r4ctntxsl');

    expect(response.status).toBe(400);
    expect(calls).toHaveLength(0);
  });

  it('refuses a zero width before it reaches the bucket', async () => {
    upstream('unused', { status: 200 });
    const response = await get('/images/width=0/6d1r4ctntxsl');

    expect(response.status).toBe(400);
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

  // Workers Caching only stores GET and HEAD, and a POST used to be answered with a
  // fresh GET to the bucket regardless.
  it('turns away a method it does not serve', async () => {
    upstream('unused', { status: 200 });
    const response = await worker.fetch(
      new Request('https://example.com/images/width=608/6d1r4ctntxsl', { method: 'POST' }),
      env
    );

    expect(response.status).toBe(405);
    expect(response.headers.get('allow')).toBe('GET, HEAD');
    expect(response.headers.get('cache-control')).toBe('no-store');
    expect(calls).toHaveLength(0);
  });

  describe('the instagram route', () => {
    it('mattes the photo onto the inner frame, then the outer one', async () => {
      upstream('original bytes', { status: 200 });
      const response = await get('/ig/1440x1700/1440x1800/6d1r4ctntxsl');

      expect(calls[0].url).toBe('https://photos.example.com/6d1r4ctntxsl');
      // Fetched untransformed: cf.image applies one transform per fetch, which is the
      // whole reason this route exists.
      expect(calls[0].options).toBeUndefined();
      expect(transforms).toEqual([
        { width: 1440, height: 1700, fit: 'pad', background: '#ffffff' },
        { width: 1440, height: 1800, fit: 'pad', background: '#ffffff' },
        { format: 'image/jpeg', quality: 100 }
      ]);
      expect(response.status).toBe(200);
      expect(response.headers.get('cache-control')).toBe('public, max-age=31536000, immutable');
      expect(response.headers.get('cache-tag')).toBe('images,images-6d1r4ctntxsl');
      expect(response.headers.get('vary')).toBeNull();
    });

    // The binding caps at 20 MB, well under the 100 MB cf.image accepts, so this route
    // can fail on an original /images/ handles fine. Better a 413 that says so than the
    // binding throwing into an indistinguishable 502.
    it('turns away an original too large for the binding', async () => {
      vi.spyOn(console, 'log').mockImplementation(() => {});
      upstream('pretend this is huge', {
        status: 200,
        headers: { 'content-length': String(21 * 1024 * 1024) }
      });

      const response = await get('/ig/1440x1700/1440x1800/6d1r4ctntxsl');

      expect(response.status).toBe(413);
      expect(response.headers.get('cache-control')).toBe('no-store');
      expect(transforms).toHaveLength(0);
    });

    it('reports an upstream failure as a failure here too', async () => {
      vi.spyOn(console, 'log').mockImplementation(() => {});
      upstream('upstream is unwell', { status: 503 });

      const response = await get('/ig/1440x1700/1440x1800/6d1r4ctntxsl');

      expect(response.status).toBe(502);
      expect(transforms).toHaveLength(0);
    });
  });
});
