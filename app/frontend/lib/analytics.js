/* global ga, gtag, gaTrackingId */
/**
 * Product-agnostic function to make a page view tracking call.
 * Currently supports GA, either directly or as part of GTM.
 * @param {string} path The pathname for the page to be tracked.
 */
export function trackPageView (path) {
  if (typeof ga !== 'undefined') {
    ga('set', 'page', path);
    ga('send', 'pageview');
  }
  if (typeof gtag !== 'undefined' && typeof gaTrackingId !== 'undefined') {
    gtag('config', gaTrackingId, { 'page_path': path });
  }
}
