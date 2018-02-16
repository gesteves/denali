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
   * Edits a tag. Sends the new tag name to the server via Fetch, receives
   * the updated tag's markup, and replaces it on the page.
   * TODO: Remove the jQuery dependency.
   * @param {Event} event A click event from the edit link.
   */
  edit (event) {
    event.preventDefault();
    const prompt = window.prompt(`What do you want to replace the “${this.data.get('name')}” tag with?`, this.data.get('name'));
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

    fetch(`${url}.js`, fetchOpts)
      .then(fetchStatus)
      .then(fetchText)
      .then(html => $(this.element).replaceWith(html));
  }

  /**
   * Deletes a tag. If the DELETE request is successful, simply removes the
   * tag's element from the page.
   * @param {Event} event A click event from the delete link.
   */
  delete (event) {
    event.preventDefault();
    if (!window.confirm(`Are you sure you want to delete the “${this.data.get('name')}” tag?`)) {
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
      .then(() => this.element.parentNode.removeChild(this.element));
  }
}
