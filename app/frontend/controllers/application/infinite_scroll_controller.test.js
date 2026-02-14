import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';
import InfiniteScrollController from './infinite_scroll_controller';
import { createIntersectionEntry } from '../../test/helpers';

describe('InfiniteScrollController', () => {
  let application;
  let element;
  let observerCallback;

  beforeEach(() => {
    // Reset fetch mock
    global.fetch = vi.fn();

    // Capture the IntersectionObserver callback
    global.IntersectionObserver = class {
      constructor(callback) {
        observerCallback = callback;
        this.elements = new Set();
      }
      observe(el) { this.elements.add(el); }
      unobserve(el) { this.elements.delete(el); }
      disconnect() { this.elements.clear(); }
    };

    document.body.innerHTML = `
      <div id="footer" style="display: block;">Footer</div>
      <div data-controller="infinite-scroll"
           data-infinite-scroll-current-page-value="1"
           data-infinite-scroll-base-url-value="/entries">
        <div data-infinite-scroll-target="container">
          <article>Entry 1</article>
        </div>
        <nav data-infinite-scroll-target="paginator" style="display: block;">
          <a href="/entries/page/2">Next</a>
        </nav>
        <div data-infinite-scroll-target="spinner" class="loading"></div>
      </div>
    `;

    element = document.querySelector('[data-controller="infinite-scroll"]');
    application = Application.start();
    application.register('infinite-scroll', InfiniteScrollController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
    vi.clearAllMocks();
  });

  function getController() {
    return application.getControllerForElementAndIdentifier(element, 'infinite-scroll');
  }

  function container() {
    return element.querySelector('[data-infinite-scroll-target="container"]');
  }

  function spinner() {
    return element.querySelector('[data-infinite-scroll-target="spinner"]');
  }

  function paginator() {
    return element.querySelector('[data-infinite-scroll-target="paginator"]');
  }

  function footer() {
    return document.querySelector('#footer');
  }

  function mockFetchSuccess(html) {
    global.fetch.mockResolvedValueOnce({
      ok: true,
      text: () => Promise.resolve(html)
    });
  }

  function mockFetchError() {
    global.fetch.mockResolvedValueOnce({
      ok: false,
      status: 404
    });
  }

  describe('connect', () => {
    it('prepares the page by showing spinner and hiding footer', () => {
      expect(spinner().classList.contains('loading--active')).toBe(true);
      expect(footer().style.display).toBe('none');
      expect(paginator().style.display).toBe('none');
    });

    it('sets up IntersectionObserver', () => {
      expect(observerCallback).toBeDefined();
    });

    it('does not initialize for bot user agents', () => {
      application.stop();
      document.body.innerHTML = '';

      // Mock bot user agent
      Object.defineProperty(navigator, 'userAgent', {
        value: 'Googlebot/2.1',
        configurable: true
      });

      document.body.innerHTML = `
        <div id="footer">Footer</div>
        <div data-controller="infinite-scroll"
             data-infinite-scroll-current-page-value="1"
             data-infinite-scroll-base-url-value="/entries">
          <div data-infinite-scroll-target="container"></div>
          <nav data-infinite-scroll-target="paginator" style="display: block;">Next</nav>
          <div data-infinite-scroll-target="spinner"></div>
        </div>
      `;

      element = document.querySelector('[data-controller="infinite-scroll"]');
      application = Application.start();
      application.register('infinite-scroll', InfiniteScrollController);

      // Footer should still be visible for bots
      expect(document.querySelector('#footer').style.display).not.toBe('none');

      // Reset user agent
      Object.defineProperty(navigator, 'userAgent', {
        value: 'Mozilla/5.0',
        configurable: true
      });
    });

    it('returns early when spinner target is missing', () => {
      application.stop();
      document.body.innerHTML = `
        <div id="footer">Footer</div>
        <div data-controller="infinite-scroll"
             data-infinite-scroll-current-page-value="1"
             data-infinite-scroll-base-url-value="/entries">
          <div data-infinite-scroll-target="container"></div>
          <nav data-infinite-scroll-target="paginator">Next</nav>
        </div>
      `;

      element = document.querySelector('[data-controller="infinite-scroll"]');
      application = Application.start();
      application.register('infinite-scroll', InfiniteScrollController);

      // Should not throw and footer should be visible
      expect(document.querySelector('#footer').style.display).not.toBe('none');
    });

    it('returns early when paginator target is missing', () => {
      application.stop();
      document.body.innerHTML = `
        <div id="footer">Footer</div>
        <div data-controller="infinite-scroll"
             data-infinite-scroll-current-page-value="1"
             data-infinite-scroll-base-url-value="/entries">
          <div data-infinite-scroll-target="container"></div>
          <div data-infinite-scroll-target="spinner"></div>
        </div>
      `;

      element = document.querySelector('[data-controller="infinite-scroll"]');
      application = Application.start();
      application.register('infinite-scroll', InfiniteScrollController);

      // Footer should be visible since controller returns early
      expect(document.querySelector('#footer').style.display).not.toBe('none');
    });
  });

  describe('handleIntersect', () => {
    it('fetches next page when spinner is visible', async () => {
      mockFetchSuccess('<article>Entry 2</article>');

      const entry = createIntersectionEntry(spinner(), true, 1);
      observerCallback([entry]);

      await vi.waitFor(() => {
        expect(global.fetch).toHaveBeenCalledWith('/entries/page/2.js');
      });
    });

    it('does not fetch when spinner is not intersecting', () => {
      const entry = createIntersectionEntry(spinner(), false, 0);
      observerCallback([entry]);

      expect(global.fetch).not.toHaveBeenCalled();
    });

    it('appends fetched HTML to container', async () => {
      mockFetchSuccess('<article>Entry 2</article>');

      const entry = createIntersectionEntry(spinner(), true, 1);
      observerCallback([entry]);

      await vi.waitFor(() => {
        expect(container().innerHTML).toContain('Entry 2');
      });
    });

    it('increments currentPageValue after successful fetch', async () => {
      mockFetchSuccess('<article>Entry 2</article>');
      const controller = getController();

      expect(controller.currentPageValue).toBe(1);

      const entry = createIntersectionEntry(spinner(), true, 1);
      observerCallback([entry]);

      await vi.waitFor(() => {
        expect(controller.currentPageValue).toBe(2);
      });
    });

    it('handles query parameter URLs correctly', async () => {
      application.stop();

      // Recapture the observer callback for this new instance
      let newObserverCallback;
      global.IntersectionObserver = class {
        constructor(callback) {
          newObserverCallback = callback;
          this.elements = new Set();
        }
        observe(el) { this.elements.add(el); }
        unobserve(el) { this.elements.delete(el); }
        disconnect() { this.elements.clear(); }
      };

      document.body.innerHTML = `
        <div id="footer">Footer</div>
        <div data-controller="infinite-scroll"
             data-infinite-scroll-current-page-value="1"
             data-infinite-scroll-base-url-value="/search?q=test">
          <div data-infinite-scroll-target="container"></div>
          <nav data-infinite-scroll-target="paginator">Next</nav>
          <div data-infinite-scroll-target="spinner"></div>
        </div>
      `;

      element = document.querySelector('[data-controller="infinite-scroll"]');
      application = Application.start();
      application.register('infinite-scroll', InfiniteScrollController);

      // Wait for Stimulus to connect
      await new Promise(resolve => setTimeout(resolve, 10));

      mockFetchSuccess('<article>Result 2</article>');

      const entry = createIntersectionEntry(
        element.querySelector('[data-infinite-scroll-target="spinner"]'),
        true, 1
      );
      newObserverCallback([entry]);

      await vi.waitFor(() => {
        expect(global.fetch).toHaveBeenCalledWith('/search.js?q=test&page=2');
      });
    });
  });

  describe('endInfiniteScroll', () => {
    it('shows footer when fetch fails', async () => {
      mockFetchError();

      const entry = createIntersectionEntry(spinner(), true, 1);
      observerCallback([entry]);

      await vi.waitFor(() => {
        expect(footer().style.display).toBe('block');
      });
    });

    it('removes spinner from DOM on error', async () => {
      mockFetchError();

      const entry = createIntersectionEntry(spinner(), true, 1);
      observerCallback([entry]);

      await vi.waitFor(() => {
        expect(element.querySelector('[data-infinite-scroll-target="spinner"]')).toBeNull();
      });
    });

    it('sets aria-busy to false on container', async () => {
      mockFetchError();

      const entry = createIntersectionEntry(spinner(), true, 1);
      observerCallback([entry]);

      await vi.waitFor(() => {
        expect(container().getAttribute('aria-busy')).toBe('false');
      });
    });
  });

  describe('animateSpinner', () => {
    it('adds loading--visible class during fetch', async () => {
      let resolvePromise;
      global.fetch.mockReturnValue(new Promise(resolve => {
        resolvePromise = resolve;
      }));

      const entry = createIntersectionEntry(spinner(), true, 1);
      observerCallback([entry]);

      await vi.waitFor(() => {
        expect(spinner().classList.contains('loading--visible')).toBe(true);
      });

      resolvePromise({ ok: true, text: () => Promise.resolve('') });
    });

    it('sets aria-busy on container during fetch', async () => {
      let resolvePromise;
      global.fetch.mockReturnValue(new Promise(resolve => {
        resolvePromise = resolve;
      }));

      const entry = createIntersectionEntry(spinner(), true, 1);
      observerCallback([entry]);

      await vi.waitFor(() => {
        expect(container().getAttribute('aria-busy')).toBe('true');
      });

      resolvePromise({ ok: true, text: () => Promise.resolve('') });
    });
  });

  describe('stopSpinner', () => {
    it('removes loading--visible class after fetch completes', async () => {
      mockFetchSuccess('<article>Entry 2</article>');

      const entry = createIntersectionEntry(spinner(), true, 1);
      observerCallback([entry]);

      await vi.waitFor(() => {
        expect(spinner().classList.contains('loading--visible')).toBe(false);
      });
    });

    it('sets aria-hidden on spinner after fetch', async () => {
      mockFetchSuccess('<article>Entry 2</article>');

      const entry = createIntersectionEntry(spinner(), true, 1);
      observerCallback([entry]);

      await vi.waitFor(() => {
        expect(spinner().getAttribute('aria-hidden')).toBe('true');
      });
    });
  });

  describe('appendPage', () => {
    it('does not append anything when html is empty', async () => {
      mockFetchSuccess('');

      const initialHTML = container().innerHTML;
      const entry = createIntersectionEntry(spinner(), true, 1);
      observerCallback([entry]);

      await vi.waitFor(() => {
        expect(global.fetch).toHaveBeenCalled();
      });

      // Give time for append to potentially happen
      await new Promise(resolve => setTimeout(resolve, 10));
      expect(container().innerHTML).toBe(initialHTML);
    });

    it('appends multiple entries', async () => {
      mockFetchSuccess('<article>Entry 2</article><article>Entry 3</article>');

      const entry = createIntersectionEntry(spinner(), true, 1);
      observerCallback([entry]);

      await vi.waitFor(() => {
        expect(container().innerHTML).toContain('Entry 2');
        expect(container().innerHTML).toContain('Entry 3');
      });
    });
  });

  describe('preparePage', () => {
    it('sets aria-hidden on footer', () => {
      expect(footer().getAttribute('aria-hidden')).toBe('true');
    });

    it('sets aria-hidden on paginator', () => {
      expect(paginator().getAttribute('aria-hidden')).toBe('true');
    });
  });

  describe('disconnect', () => {
    it('disconnects the IntersectionObserver', () => {
      const controller = getController();
      controller.disconnect();
      expect(controller.observer.elements.size).toBe(0);
    });

    it('restores footer visibility', () => {
      expect(footer().style.display).toBe('none');
      const controller = getController();
      controller.disconnect();
      expect(footer().style.display).toBe('block');
    });

    it('restores footer aria-hidden', () => {
      expect(footer().getAttribute('aria-hidden')).toBe('true');
      const controller = getController();
      controller.disconnect();
      expect(footer().getAttribute('aria-hidden')).toBe('false');
    });
  });
});
