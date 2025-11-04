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
 */
export function trackPageView() {
  setUpPlausible();

  // Extract the 'q' query parameter
  const currentUrl = new URL(window.location.href);
  const queryParams = currentUrl.searchParams;
  const searchQuery = queryParams.get('q');

  // Prepare the parameters object, including the page URL
  const params = { u: currentUrl.href };

  // If 'q' parameter exists, add 'search_query' to the properties
  if (searchQuery) {
    params.props = { search_query: searchQuery };
  }

  // Send the pageview event to Plausible with the parameters
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
  plausible(event, { props: props });
}

/**
 * Removes specific UTM parameters and other query parameters from the page URL.
 * This function modifies the current URL by removing marketing and tracking parameters,
 * then updates the browser's history state to reflect the clean URL.
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
