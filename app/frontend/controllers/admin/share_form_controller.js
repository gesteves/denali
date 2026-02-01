import { Controller } from '@hotwired/stimulus';

/**
 * Handles XHR form submission for each platform sharing section.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['text', 'scheduledAt', 'submit', 'inReplyTo', 'quote', 'crop'];
  static values = {
    url: String,
    platform: String
  }

  /**
   * Submits the share form via XHR.
   * @param {Event} event Click event from the submit button.
   */
  async submit (event) {
    event.preventDefault();

    this.submitTarget.disabled = true;
    this.submitTarget.classList.add('is-loading');

    const formData = this.buildFormData();
    const csrfToken = document.querySelector('meta[name="csrf-token"]').content;

    try {
      const response = await fetch(this.urlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'text/vnd.turbo-stream.html, application/json',
          'X-CSRF-Token': csrfToken
        },
        body: JSON.stringify(formData)
      });

      const contentType = response.headers.get('Content-Type') || '';

      if (contentType.includes('text/vnd.turbo-stream.html')) {
        const html = await response.text();
        Turbo.renderStreamMessage(html);
      } else {
        const data = await response.json();
        this.notify(data.status, data.message);
      }
    } catch (error) {
      this.notify('danger', `Failed to share on ${this.platformValue}. Please try again.`);
    } finally {
      this.submitTarget.disabled = false;
      this.submitTarget.classList.remove('is-loading');
    }
  }

  /**
   * Builds the form data object based on available targets.
   * @returns {Object} The form data to submit.
   */
  buildFormData () {
    const data = {};

    if (this.hasTextTarget) {
      data.text = this.textTarget.value;
    }

    if (this.hasScheduledAtTarget) {
      data.scheduled_at = this.scheduledAtTarget.value;
    }

    if (this.hasInReplyToTarget) {
      data.in_reply_to = this.inReplyToTarget.value;
    }

    if (this.hasQuoteTarget) {
      data.quote = this.quoteTarget.value;
    }

    if (this.hasCropTarget) {
      data.crop = this.cropTarget.value;
    }

    return data;
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
