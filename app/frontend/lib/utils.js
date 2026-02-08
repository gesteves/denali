/**
 * Dispatches a custom `notify` event to trigger a notification
 * @param {string} message The text for the notification
 * @param {string} status The type of notification
 */
export function sendNotification (message, status = 'success') {
  const event = new CustomEvent('notify', {
    detail: {
      message,
      status
    }
  });
  document.body.dispatchEvent(event);
}

/**
 * Checks if the device supports hover interactions or not
 * @return {boolean} Whether or not the device supports hover
 */
export function supportsHover () {
  return window.matchMedia('(hover: hover)').matches;
}
