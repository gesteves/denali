import { Controller } from 'stimulus';
import { fetchStatus, fetchText } from '../../lib/utils';
import $ from 'jquery';

/**
 * Controls editing and deleting tags.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['form', 'select', 'thumbnails'];

  connect () {
    // Grab the CSRF token from the document head so we can send it in Fetch requests
    this.csrfToken = document.querySelector('[name=csrf-token]').getAttribute('content');
  }

  /**
   * Fetches the requested size and inserts the result into the thumb container
   * TODO: Remove the jQuery dependency.
   * @param {Event} event A submit event from the form.
   */
  fetch (event) {
    event.preventDefault();
    const url = this.formTarget.action;
    let size = this.selectTarget.value;

    if (size === '') {
      return;
    }

    if (size === 'other') {
      size = parseInt(window.prompt('What width, in pixels, would you like?'));

      if (isNaN(size)) {
        this.formTarget.reset();
        window.alert('That’s not a valid size!');
        return;
      }
    }

    const fetchOpts = {
      method: 'POST',
      headers: new Headers({
        'X-CSRF-Token': this.csrfToken
      }),
      credentials: 'include'
    };

    fetch(`${url}.js?size=${size}`, fetchOpts)
      .then(fetchStatus)
      .then(fetchText)
      .then(html => $(this.thumbnailsTarget).html(html));
  }
}
