import { Controller } from '@hotwired/stimulus';

/**
 * Handles XHR form submission for each platform sharing section.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['text', 'scheduledAt', 'submit', 'stats', 'inReplyTo', 'quote', 'crop'];
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
          'Accept': 'application/json',
          'X-CSRF-Token': csrfToken
        },
        body: JSON.stringify(formData)
      });

      const data = await response.json();

      this.notify(data.status, data.message);

      if (data.status === 'success' && this.hasStatsTarget) {
        this.updateStats(data);
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
   * Updates the stats section after a successful share.
   * @param {Object} data The response data from the server.
   */
  updateStats (data) {
    if (!data.last_shared_at || data.scheduled) {
      return;
    }

    // Build updated stats HTML
    const lastSharedClass = 'tag is-danger';
    const statsHtml = `
      <div class="control">
        <div class="tags has-addons">
          <span class="${lastSharedClass}">Last shared</span>
          <span class="tag" title="${data.last_shared_at}">just now</span>
        </div>
      </div>
      <div class="control">
        <div class="tags has-addons">
          <span class="tag is-info">Shares</span>
          <span class="tag">${data.shares_count}</span>
        </div>
      </div>
    `;

    this.statsTarget.innerHTML = statsHtml;
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
