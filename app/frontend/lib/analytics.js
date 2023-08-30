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
 * Removes UTM params and other crap from the page URL
 */
export function cleanUpUrl() {
  if (window.location.search) {
    const cleanURL = window.location.origin + window.location.pathname;
    window.history.replaceState({}, document.title, cleanURL);
  }
}
