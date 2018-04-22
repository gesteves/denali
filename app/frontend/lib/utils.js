/**
 * Convenience function to resolve or reject a promise depending on
 * the response received by a fetch call. The Promise returned from fetch
 * won’t reject on HTTP error status, so we gotta do it ourselves.
 * @param {Response} response Fetch response
 * @return {Promise} A promise that resolves to the server response, or
 * is rejected if the server returns anything other than ok (e.g. 404)
 */
export function fetchStatus (response) {
  if (response.ok) {
    return Promise.resolve(response);
  } else {
    return Promise.reject();
  }
}

/**
 * Convenience function to return the Promise from response.json()
 * @param {Response} response Fetch response
 * @return {Promise} A promise that resolves to the parsed JSON
 */
export function fetchJson(response) {
  return response.json();
}

/**
 * Convenience function to return the Promise from response.text()
 * @param {Response} response Fetch response
 * @return {Promise} A promise that resolves to the response text
 */
export function fetchText(response) {
  return response.text();
}

/**
 * Dispatches a custom `notify` event to trigger a notification
 * @param {string} message The text for the notification
 * @param {string} status The type of notification
 */
export function sendNotification (message, status = 'success') {
  const event = new CustomEvent('notify', {
    detail: {
      message: message,
      status: status
    }
  });
  document.body.dispatchEvent(event);
}
