import { describe, it, expect, beforeEach, vi } from 'vitest';

vi.mock('../lib/analytics', () => ({
  trackPageView: vi.fn()
}));

describe('Pagination', () => {
  let Pagination;
  let observerInstance;
  let observerCallback;
  let trackPageView;

  beforeEach(async () => {
    vi.resetModules();

    observerInstance = null;
    observerCallback = null;

    global.IntersectionObserver = vi.fn(function (callback, options) {
      observerCallback = callback;
      observerInstance = this;
      this.observe = vi.fn();
      this.unobserve = vi.fn();
      this.disconnect = vi.fn();
      this._options = options;
    });

    const mod = await import('./pagination.js');
    Pagination = mod.default;

    const analytics = await import('../lib/analytics');
    trackPageView = analytics.trackPageView;
  });

  describe('observe', () => {
    it('delegates to observer.observe', () => {
      const element = document.createElement('div');
      Pagination.observe(element);
      expect(observerInstance.observe).toHaveBeenCalledWith(element);
    });

    it('returns early without error when IntersectionObserver is not available', () => {
      delete global.IntersectionObserver;
      const element = document.createElement('div');
      expect(() => Pagination.observe(element)).not.toThrow();
    });
  });

  describe('unobserve', () => {
    it('delegates to observer.unobserve', () => {
      const element = document.createElement('div');
      Pagination.observe(element);
      Pagination.unobserve(element);
      expect(observerInstance.unobserve).toHaveBeenCalledWith(element);
    });

    it('returns early without error when IntersectionObserver is not available', () => {
      delete global.IntersectionObserver;
      const element = document.createElement('div');
      expect(() => Pagination.unobserve(element)).not.toThrow();
    });
  });

  describe('singleton', () => {
    it('creates only one IntersectionObserver for multiple observe calls', () => {
      Pagination.observe(document.createElement('div'));
      Pagination.observe(document.createElement('div'));
      Pagination.observe(document.createElement('div'));
      expect(global.IntersectionObserver).toHaveBeenCalledTimes(1);
    });
  });

  describe('handleIntersection', () => {
    it('calls replaceState with the page URL from the intersecting entry', () => {
      const element = document.createElement('div');
      element.setAttribute('data-pagination-page-url', '/page/2');
      Pagination.observe(element);

      Object.defineProperty(window, 'location', {
        value: { pathname: '/page/2' },
        writable: true,
        configurable: true
      });

      observerCallback([{ target: element, intersectionRatio: 1, isIntersecting: true }]);

      expect(window.history.replaceState).toHaveBeenCalledWith(null, null, '/page/2');
    });

    it('does nothing when no entries are intersecting', () => {
      const element = document.createElement('div');
      element.setAttribute('data-pagination-page-url', '/page/2');
      Pagination.observe(element);

      observerCallback([{ target: element, intersectionRatio: 0, isIntersecting: false }]);

      expect(window.history.replaceState).not.toHaveBeenCalled();
    });

    it('does not call trackPageView when the URL stays the same', () => {
      const element = document.createElement('div');
      element.setAttribute('data-pagination-page-url', '/page/1');
      Pagination.observe(element);

      Object.defineProperty(window, 'location', {
        value: { pathname: '/page/1' },
        writable: true,
        configurable: true
      });

      observerCallback([{ target: element, intersectionRatio: 1, isIntersecting: true }]);

      expect(window.history.replaceState).toHaveBeenCalled();
      expect(trackPageView).not.toHaveBeenCalled();
    });

    it('calls trackPageView when the URL changes', () => {
      const element = document.createElement('div');
      element.setAttribute('data-pagination-page-url', '/page/3');
      Pagination.observe(element);

      const loc = { pathname: '/page/1' };
      Object.defineProperty(window, 'location', {
        value: loc,
        writable: true,
        configurable: true
      });

      window.history.replaceState.mockImplementation(() => {
        loc.pathname = '/page/3';
      });

      observerCallback([{ target: element, intersectionRatio: 1, isIntersecting: true }]);

      expect(window.history.replaceState).toHaveBeenCalledWith(null, null, '/page/3');
      expect(trackPageView).toHaveBeenCalled();
    });

    it('does not call replaceState or trackPageView when data attribute is missing', () => {
      const element = document.createElement('div');
      Pagination.observe(element);

      observerCallback([{ target: element, intersectionRatio: 1, isIntersecting: true }]);

      expect(window.history.replaceState).not.toHaveBeenCalled();
      expect(trackPageView).not.toHaveBeenCalled();
    });
  });
});
