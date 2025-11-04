/* global plausible */

/**
 * Sets up the Plausible analytics queue if it doesn't already exist.
 */
function setUpPlausible() {
  window.plausible =
    window.plausible ||
    function () {
      (window.plausible.q = window.plausible.q || []).push(arguments);
    };
  window.plausible.init =
    window.plausible.init ||
    function (i) {
      window.plausible.o = i || {};
    };
  window.plausible.init({ autoCapturePageviews: false });
}

/**
 * Product-agnostic function to make a page view tracking call.
 * Currently supports Plausible.
 * @param {Object} additionalProps - Optional additional properties to include with the pageview.
 */
export function trackPageView(additionalProps = {}) {
  setUpPlausible();

  const currentUrl = new URL(window.location.href);
  const searchQuery = currentUrl.searchParams.get('q');

  const params = { u: currentUrl.href };

  // Combine search query with any additional props
  if (searchQuery || Object.keys(additionalProps).length > 0) {
    params.props = { ...additionalProps };
    if (searchQuery) {
      params.props.search_query = searchQuery;
    }
  }

  plausible('pageview', params);
  cleanUpUrl();
}

/**
 * Product-agnostic function to make an event tracking call.
 * Currently supports Plausible.
 * @param {string} event - The event name to be tracked.
 * @param {Object} props - Additional properties to send with the event.
 */
export function trackEvent(event, props = {}) {
  setUpPlausible();
  plausible(event, { props });
}

/**
 * Removes specific UTM parameters and other query parameters from the page URL.
 * This function modifies the current URL by removing marketing and tracking parameters,
 * then updates the browser's history state to reflect the clean URL.
 */
export function cleanUpUrl() {
  const currentUrl = new URL(window.location.href);
  const params = currentUrl.searchParams;

  const paramsToRemove = [
    'ref',
    'source',
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'utm_content',
    'utm_term',
  ];

  let paramRemoved = false;

  paramsToRemove.forEach((param) => {
    if (params.has(param)) {
      params.delete(param);
      paramRemoved = true;
    }
  });

  if (paramRemoved) {
    const cleanURL =
      window.location.origin +
      window.location.pathname +
      (params.toString() ? '?' + params.toString() : '');
    window.history.replaceState({}, document.title, cleanURL);
  }
}
