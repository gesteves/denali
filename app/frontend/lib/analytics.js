/* global plausible */

/**
 * Product-agnostic function to make a page view tracking call.
 * Currently supports Plausible.
 */
export function trackPageView () {
  if (typeof plausible !== 'undefined') {
    plausible('pageview');
  }
}

/**
 * Product-agnostic function to make an event tracking call.
 * Currently supports Plausible.
 */
export function trackEvent(event, props = {}) {
  if (typeof plausible !== 'undefined') {
    plausible(event, { props: props });
  }
}

