/* global plausible */

function setupPlausibleQueue() {
  window.plausible = window.plausible || function() {
    (window.plausible.q = window.plausible.q || []).push(arguments);
  }
}

/**
 * Product-agnostic function to make a page view tracking call.
 * Currently supports Plausible.
 */
export function trackPageView() {
  setupPlausibleQueue();
  plausible('pageview');
  cleanUpUrl();
}

/**
 * Product-agnostic function to make an event tracking call.
 * Currently supports Plausible.
 */
export function trackEvent(event, props = {}) {
  setupPlausibleQueue();
  plausible(event, { props: props });
}

/**
 * Removes specific UTM params and other query parameters from the page URL.
 */
export function cleanUpUrl() {
  const currentUrl = new URL(window.location.href);
  const params = currentUrl.searchParams;

  // List of query parameters to remove
  const paramsToRemove = [
      'ref',
      'source',
      'utm_source',
      'utm_medium',
      'utm_campaign',
      'utm_content',
      'utm_term'
  ];

  paramsToRemove.forEach(param => {
      params.delete(param);
  });

  const cleanURL = window.location.origin + window.location.pathname + (params.toString() ? '?' + params.toString() : '');
  window.history.replaceState({}, document.title, cleanURL);
}

