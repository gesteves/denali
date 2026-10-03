import { describe, it, expect, beforeEach, vi } from 'vitest';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

// The worker is served from an ERB view with no ERB in it, so it's run here as
// plain JS against a fake worker global.
const source = readFileSync(resolve(__dirname, '../../views/service_worker/index.js.erb'), 'utf8');

function loadWorker () {
  const listeners = {};
  const worker = {
    addEventListener: (type, listener) => { listeners[type] = listener; },
    skipWaiting: vi.fn(),
    registration: { showNotification: vi.fn(() => Promise.resolve()) },
    clients: {
      claim: vi.fn(() => Promise.resolve()),
      matchAll: vi.fn(() => Promise.resolve([])),
      openWindow: vi.fn(() => Promise.resolve())
    }
  };
  const caches = {
    keys: vi.fn(() => Promise.resolve(['denali-v1', 'denali-v2'])),
    delete: vi.fn(() => Promise.resolve(true))
  };
  new Function('self', 'caches', source)(worker, caches);

  // Runs a listener and waits for whatever it handed to waitUntil.
  const dispatch = async (type, event = {}) => {
    let pending = Promise.resolve();
    listeners[type]({ ...event, waitUntil: promise => { pending = promise; } });
    await pending;
  };

  return { worker, caches, dispatch };
}

describe('service worker', () => {
  let sw;

  beforeEach(() => {
    sw = loadWorker();
  });

  describe('activate', () => {
    it('deletes every cache left on the origin and claims open pages', async () => {
      await sw.dispatch('activate');

      expect(sw.caches.delete).toHaveBeenCalledWith('denali-v1');
      expect(sw.caches.delete).toHaveBeenCalledWith('denali-v2');
      expect(sw.worker.clients.claim).toHaveBeenCalled();
    });
  });

  describe('push', () => {
    it('shows a notification from the payload', async () => {
      const payload = { title: 'New photo published', body: 'A title', url: 'https://example.com/1/a' };
      await sw.dispatch('push', { data: { json: () => payload } });

      expect(sw.worker.registration.showNotification).toHaveBeenCalledWith(
        'New photo published',
        expect.objectContaining({ body: 'A title', data: expect.objectContaining({ url: 'https://example.com/1/a' }) })
      );
    });

    it('ignores a push without a payload', async () => {
      await expect(sw.dispatch('push', { data: null })).resolves.toBeUndefined();
      expect(sw.worker.registration.showNotification).not.toHaveBeenCalled();
    });

    it('ignores a payload that is not JSON', async () => {
      await sw.dispatch('push', { data: { json: () => { throw new SyntaxError('bad'); } } });
      expect(sw.worker.registration.showNotification).not.toHaveBeenCalled();
    });
  });

  describe('notificationclick', () => {
    const click = url => ({ notification: { close: vi.fn(), data: { url } } });

    it('focuses a tab already showing the entry', async () => {
      const tab = { url: 'https://example.com/1/a', focus: vi.fn() };
      sw.worker.clients.matchAll.mockResolvedValue([tab]);

      await sw.dispatch('notificationclick', click('https://example.com/1/a?utm_source=Push'));

      expect(tab.focus).toHaveBeenCalled();
      expect(sw.worker.clients.openWindow).not.toHaveBeenCalled();
    });

    it('opens a new tab otherwise', async () => {
      await sw.dispatch('notificationclick', click('https://example.com/1/a'));
      expect(sw.worker.clients.openWindow).toHaveBeenCalledWith('https://example.com/1/a');
    });

    it('just closes a notification without a URL', async () => {
      const event = click(undefined);
      await sw.dispatch('notificationclick', event);

      expect(event.notification.close).toHaveBeenCalled();
      expect(sw.worker.clients.openWindow).not.toHaveBeenCalled();
    });
  });
});
