import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest';
import { trackPageView, trackEvent, cleanUpUrl } from './analytics';

describe('analytics', () => {
  let originalLocation;

  beforeEach(() => {
    // Reset plausible mock
    global.plausible = vi.fn();

    // Reset window.history mock
    window.history.replaceState.mockClear();

    // Store original location
    originalLocation = window.location;
  });

  afterEach(() => {
    // Restore original location
    Object.defineProperty(window, 'location', {
      value: originalLocation,
      writable: true,
      configurable: true
    });
  });

  function setUrl(url) {
    const urlObj = new URL(url);
    Object.defineProperty(window, 'location', {
      value: {
        href: urlObj.href,
        origin: urlObj.origin,
        pathname: urlObj.pathname,
        search: urlObj.search,
        searchParams: urlObj.searchParams
      },
      writable: true,
      configurable: true
    });
  }

  describe('trackPageView', () => {
    it('calls plausible with current URL', () => {
      setUrl('https://example.com/page');

      trackPageView();

      expect(global.plausible).toHaveBeenCalledWith('pageview', {
        u: 'https://example.com/page'
      });
    });

    it('includes search_query when ?q= parameter present', () => {
      setUrl('https://example.com/search?q=test+query');

      trackPageView();

      expect(global.plausible).toHaveBeenCalledWith('pageview', {
        u: 'https://example.com/search?q=test+query',
        props: { search_query: 'test query' }
      });
    });

    it('includes additional props when provided', () => {
      setUrl('https://example.com/page');

      trackPageView({ custom_prop: 'value' });

      expect(global.plausible).toHaveBeenCalledWith('pageview', {
        u: 'https://example.com/page',
        props: { custom_prop: 'value' }
      });
    });

    it('combines search_query with additional props', () => {
      setUrl('https://example.com/search?q=test');

      trackPageView({ custom_prop: 'value' });

      expect(global.plausible).toHaveBeenCalledWith('pageview', {
        u: 'https://example.com/search?q=test',
        props: { custom_prop: 'value', search_query: 'test' }
      });
    });

    it('calls cleanUpUrl after tracking', () => {
      setUrl('https://example.com/page?utm_source=twitter');

      trackPageView();

      expect(window.history.replaceState).toHaveBeenCalled();
    });

    it('initializes plausible with the proxied endpoint and manual pageviews', () => {
      setUrl('https://example.com/page');
      const initSpy = vi.fn();
      global.plausible.init = initSpy;

      trackPageView();

      expect(initSpy).toHaveBeenCalledWith({
        autoCapturePageviews: false,
        endpoint: '/pa/event'
      });
    });
  });

  describe('trackEvent', () => {
    it('calls plausible with event name', () => {
      trackEvent('button_click');

      expect(global.plausible).toHaveBeenCalledWith('button_click', { props: {} });
    });

    it('includes props when provided', () => {
      trackEvent('form_submit', { form_name: 'contact' });

      expect(global.plausible).toHaveBeenCalledWith('form_submit', {
        props: { form_name: 'contact' }
      });
    });
  });

  describe('cleanUpUrl', () => {
    it('removes utm_source parameter', () => {
      setUrl('https://example.com/page?utm_source=twitter');

      cleanUpUrl();

      expect(window.history.replaceState).toHaveBeenCalledWith(
        {},
        document.title,
        'https://example.com/page'
      );
    });

    it('removes utm_medium parameter', () => {
      setUrl('https://example.com/page?utm_medium=social');

      cleanUpUrl();

      expect(window.history.replaceState).toHaveBeenCalledWith(
        {},
        document.title,
        'https://example.com/page'
      );
    });

    it('removes utm_campaign parameter', () => {
      setUrl('https://example.com/page?utm_campaign=launch');

      cleanUpUrl();

      expect(window.history.replaceState).toHaveBeenCalledWith(
        {},
        document.title,
        'https://example.com/page'
      );
    });

    it('removes utm_content parameter', () => {
      setUrl('https://example.com/page?utm_content=banner');

      cleanUpUrl();

      expect(window.history.replaceState).toHaveBeenCalledWith(
        {},
        document.title,
        'https://example.com/page'
      );
    });

    it('removes utm_term parameter', () => {
      setUrl('https://example.com/page?utm_term=keyword');

      cleanUpUrl();

      expect(window.history.replaceState).toHaveBeenCalledWith(
        {},
        document.title,
        'https://example.com/page'
      );
    });

    it('removes ref parameter', () => {
      setUrl('https://example.com/page?ref=newsletter');

      cleanUpUrl();

      expect(window.history.replaceState).toHaveBeenCalledWith(
        {},
        document.title,
        'https://example.com/page'
      );
    });

    it('removes source parameter', () => {
      setUrl('https://example.com/page?source=email');

      cleanUpUrl();

      expect(window.history.replaceState).toHaveBeenCalledWith(
        {},
        document.title,
        'https://example.com/page'
      );
    });

    it('removes multiple UTM parameters at once', () => {
      setUrl('https://example.com/page?utm_source=twitter&utm_medium=social&utm_campaign=launch');

      cleanUpUrl();

      expect(window.history.replaceState).toHaveBeenCalledWith(
        {},
        document.title,
        'https://example.com/page'
      );
    });

    it('preserves non-UTM parameters', () => {
      setUrl('https://example.com/page?q=search&utm_source=twitter&page=2');

      cleanUpUrl();

      expect(window.history.replaceState).toHaveBeenCalledWith(
        {},
        document.title,
        'https://example.com/page?q=search&page=2'
      );
    });

    it('does not call replaceState when no UTM parameters present', () => {
      setUrl('https://example.com/page?q=search&page=2');

      cleanUpUrl();

      expect(window.history.replaceState).not.toHaveBeenCalled();
    });

    it('handles URL with no query parameters', () => {
      setUrl('https://example.com/page');

      cleanUpUrl();

      expect(window.history.replaceState).not.toHaveBeenCalled();
    });

    it('preserves path when removing parameters', () => {
      setUrl('https://example.com/blog/post?utm_source=twitter');

      cleanUpUrl();

      expect(window.history.replaceState).toHaveBeenCalledWith(
        {},
        document.title,
        'https://example.com/blog/post'
      );
    });
  });
});
