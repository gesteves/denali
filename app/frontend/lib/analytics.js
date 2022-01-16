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
