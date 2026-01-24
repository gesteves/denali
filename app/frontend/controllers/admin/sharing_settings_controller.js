import { Controller } from '@hotwired/stimulus';

/**
 * Handles auto-save for sharing settings toggles.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['blueskyField', 'mastodonField', 'instagramField', 'threadsField'];
  static values = {
    url: String
  }

  /**
   * Saves the sharing settings via XHR when a toggle changes.
   * @param {Event} event Change event from the toggle.
   */
  async save (event) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]').content;

    const formData = {
      entry: {
        post_to_bluesky: this.blueskyFieldTarget.value === 'true',
        post_to_mastodon: this.mastodonFieldTarget.value === 'true',
        post_to_instagram: this.instagramFieldTarget.value === 'true',
        post_to_threads: this.threadsFieldTarget.value === 'true'
      }
    };

    try {
      const response = await fetch(this.urlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': csrfToken
        },
        body: JSON.stringify(formData)
      });

      const data = await response.json();

      this.notify(data.status, data.message);
    } catch (error) {
      this.notify('danger', 'Failed to save sharing settings. Please try again.');
    }
  }

  /**
   * Dispatches a notify event to show a notification.
   * @param {string} status The notification status (success, danger, warning, etc.).
   * @param {string} message The notification message.
   */
  notify (status, message) {
    const event = new CustomEvent('notify', {
      bubbles: true,
      detail: { status, message }
    });
    document.body.dispatchEvent(event);
  }
}
