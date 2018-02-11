// Makes a page view tracking call
export function trackPageView () {
  if ('requestIdleCallback' in window) {
    requestIdleCallback(trackPage);
  } else {
    trackPage();
  }
}

// Makes the actual page view tracking call, in GA or GTM
function trackPage () {
  if (typeof ga !== 'undefined') {
    ga('set', 'page', window.location.pathname);
    ga('send', 'pageview');
  }
  if (typeof gtag !== 'undefined' && typeof gaTrackingId !== 'undefined') {
    gtag('config', gaTrackingId, { 'page_path': window.location.pathname });
  }
}
