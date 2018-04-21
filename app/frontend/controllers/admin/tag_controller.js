import { Controller } from 'stimulus';
import { fetchStatus, fetchText } from '../../lib/utils';
import $ from 'jquery';

/**
 * Controls editing and deleting tags.
 * @extends Controller
 */
export default class extends Controller {
  connect () {
    // Grab the CSRF token from the document head so we can send it in Fetch requests
    this.csrfToken = document.querySelector('[name=csrf-token]').getAttribute('content');
  }

  /**
   * Adds a tag to the entries with the current tag. Sends the new tag name to the
   * server via Fetch, receives the updated tag's markup, and replaces it on the page.
   * TODO: Remove the jQuery dependency.
   * @param {Event} event A click event from the add link.
   */
  add (event) {
    event.preventDefault();
    const tagName = this.data.get('name');
    const prompt = window.prompt(`Which tag do you want to add to entries tagged with “${tagName}”?`);
    if (prompt.replace(/\s/g, '').length === 0 || prompt === null) {
      return;
    }
    const link = event.target;
    const url = link.href;

    const fetchOpts = {
      method: 'POST',
      body: JSON.stringify({ tags: prompt }),
      headers: new Headers({
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.csrfToken
      }),
      credentials: 'include'
    };

    fetch(`${url}.json`, fetchOpts)
      .then(fetchStatus)
      .then(() => this.dispatchEvent(`The “${prompt}” tag has been added to all the entries tagged “${tagName}”.`));
  }

  /**
   * Edits a tag. Sends the new tag name to the server via Fetch, receives
   * the updated tag's markup, and replaces it on the page.
   * TODO: Remove the jQuery dependency.
   * @param {Event} event A click event from the edit link.
   */
  edit (event) {
    event.preventDefault();
    const tagName = this.data.get('name');
    const prompt = window.prompt(`What do you want to rename the “${tagName}” tag to?`, tagName);
    if (prompt.replace(/\s/g, '').length === 0 || prompt === null) {
      return;
    }
    const link = event.target;
    const url = link.href;

    const fetchOpts = {
      method: 'PATCH',
      body: JSON.stringify({ name: prompt }),
      headers: new Headers({
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.csrfToken
      }),
      credentials: 'include'
    };

    fetch(`${url}.json`, fetchOpts)
      .then(fetchStatus)
      .then(fetchText)
      .then(html => {
        $(this.element).replaceWith(html);
        this.dispatchEvent(`The “${tagName}” tag has been renamed to “${prompt}”.`);
      });
  }

  /**
   * Deletes a tag. If the DELETE request is successful, simply removes the
   * tag's element from the page.
   * @param {Event} event A click event from the delete link.
   */
  delete (event) {
    event.preventDefault();
    const tagName = this.data.get('name');
    if (!window.confirm(`Are you sure you want to delete the “${tagName}” tag?`)) {
      return;
    }

    const link = event.target;
    const url = link.href;

    const fetchOpts = {
      method: 'DELETE',
      headers: new Headers({
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.csrfToken
      }),
      credentials: 'include'
    };

    fetch(`${url}.json`, fetchOpts)
      .then(fetchStatus)
      .then(() => {
        this.element.parentNode.removeChild(this.element);
        this.dispatchEvent(`The “${tagName}” tag has been deleted!`);
      });
  }

  /**
   * Dispatches a custom `notify` event to trigger a notification
   * @param {string} message The text for the notification
   * * @param {string} status The type of notification
   */
  dispatchEvent (message, status = 'success') {
    const event = new CustomEvent('notify', {
      detail: {
        message: message,
        status: status
      }
    });
    document.body.dispatchEvent(event);
  }
}
