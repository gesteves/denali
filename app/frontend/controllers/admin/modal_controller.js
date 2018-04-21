import { Controller } from 'stimulus';
import { fetchStatus, fetchText } from '../../lib/utils';
import $ from 'jquery';

/**
 * Controls the modals.
 * @extends Controller
 */
export default class extends Controller {

  connect () {
    // Grab the CSRF token from the document head so we can send it in Fetch requests
    this.csrfToken = document.querySelector('[name=csrf-token]').getAttribute('content');
  }

  open (event) {
    event.preventDefault();
    const url = this.element.href;

    const fetchOpts = {
      method: 'GET',
      headers: new Headers({
        'X-CSRF-Token': this.csrfToken
      }),
      credentials: 'include'
    };

    fetch(`${url}?modal=true`, fetchOpts)
      .then(fetchStatus)
      .then(fetchText)
      .then(html => $('body').append(html));
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
