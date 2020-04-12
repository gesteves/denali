/* global clicky */

/**
 * Product-agnostic function to make a page view tracking call.
 * Currently supports Clicky.
 * @param {string} path The pathname for the page to be tracked.
 */
export function trackPageView (path) {
  if (typeof clicky !== 'undefined') {
    clicky.log(path, document.title, 'pageview');
  }
}

/**
 * Tracks an event in Clicky
 * @param {string} label The label for the event to be tracked.
 */
export function trackEvent (label) {
  if (typeof clicky !== 'undefined') {
    clicky.log(`${window.location.pathname}#${label}`, label, 'click');
  }
}
