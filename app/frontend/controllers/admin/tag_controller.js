import { Controller } from '@hotwired/stimulus';
import { sendNotification } from '../../lib/utils';

/**
 * Controls editing and deleting tags.
 * @extends Controller
 */
export default class extends Controller {
  static values = {
    name: String
  }

  connect () {
    // Grab the CSRF token from the document head so we can send it in Fetch requests
    this.csrfToken = document.querySelector('[name=csrf-token]').getAttribute('content');
  }

  /**
   * Adds a tag to the entries with the current tag. Sends the new tag name to the
   * server via Fetch, receives the updated tag's markup, and replaces it on the page.
   * @param {Event} event A click event from the add link.
   */
  async add (event) {
    event.preventDefault();
    const prompt = window.prompt(`Which tag do you want to add to entries tagged with "${this.nameValue}"?`);
    if (prompt === null || prompt.trim().length === 0) {
      return;
    }
    const url = event.target.href;

    const response = await fetch(`${url}.json`, {
      method: 'POST',
      body: JSON.stringify({ tags: prompt }),
      headers: new Headers({
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.csrfToken
      }),
      credentials: 'include'
    });
    if (!response.ok) return;
    const json = await response.json();
    sendNotification(json.message, json.status);
  }

  /**
   * Edits a tag. Sends the new tag name to the server via Fetch, receives
   * the updated tag's markup, and replaces it on the page.
   * @param {Event} event A click event from the edit link.
   */
  async edit (event) {
    event.preventDefault();
    const prompt = window.prompt(`What do you want to rename the "${this.nameValue}" tag to?`, this.nameValue);
    if (prompt === null || prompt.trim().length === 0) {
      return;
    }
    const url = event.target.href;

    const response = await fetch(`${url}.json`, {
      method: 'PATCH',
      body: JSON.stringify({ name: prompt }),
      headers: new Headers({
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.csrfToken
      }),
      credentials: 'include'
    });
    if (!response.ok) return;
    const html = await response.text();
    this.element.outerHTML = html;
    sendNotification(`The "${this.nameValue}" tag has been renamed to "${prompt}".`);
  }

  /**
   * Deletes a tag. If the DELETE request is successful, simply removes the
   * tag's element from the page.
   * @param {Event} event A click event from the delete link.
   */
  async delete (event) {
    event.preventDefault();
    if (!window.confirm(`Are you sure you want to delete the "${this.nameValue}" tag?`)) {
      return;
    }

    const url = event.target.href;

    const response = await fetch(`${url}.json`, {
      method: 'DELETE',
      headers: new Headers({
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.csrfToken
      }),
      credentials: 'include'
    });
    if (!response.ok) return;
    const json = await response.json();
    this.element.remove();
    sendNotification(json.message, json.status);
  }
}
