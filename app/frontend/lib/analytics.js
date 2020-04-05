/* global clicky */

/**
 * Product-agnostic function to make an event tracking call.
 * Currently supports Clicky
 * @param {string} path The pathname for the page to be tracked.
 */
export function trackEvent (url, label, type) {
  if (typeof clicky !== 'undefined') {
    clicky.log(url, label, type);
  }
}
