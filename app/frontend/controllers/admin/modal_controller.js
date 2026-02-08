import { Controller } from '@hotwired/stimulus';

/**
 * Controls the modals.
 * @extends Controller
 */
export default class extends Controller {

  connect () {
    // Grab the CSRF token from the document head so we can send it in Fetch requests
    this.csrfToken = document.querySelector('[name=csrf-token]').getAttribute('content');
  }

  /**
   * Fetches the button's destination and opens it in a modal window.
   * @param {Event} event A click event from the button.
   */
  async open (event) {
    event.preventDefault();
    const url = this.element.href;

    const response = await fetch(`${url}?modal=true`, {
      method: 'GET',
      headers: new Headers({ 'X-CSRF-Token': this.csrfToken }),
      credentials: 'include'
    });
    if (!response.ok) return;
    const html = await response.text();
    document.body.insertAdjacentHTML('beforeend', html);
  }

  /**
   * Closes the modal
   * @param {Event} event Click event from the close button.
   */
  close (event) {
    event.preventDefault();
    this.element.remove();
  }
}
