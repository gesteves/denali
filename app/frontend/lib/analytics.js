/* global plausible, clicky */

/**
 * Product-agnostic function to make a page view tracking call.
 * Currently supports Plausible.
 */
export function trackPageView () {
  if (typeof plausible !== 'undefined') {
    plausible('pageview');
  }
  if (typeof clicky !== 'undefined') {
    clicky.log(window.location.pathname, document.title, 'pageview');
  }
}
