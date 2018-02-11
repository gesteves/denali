import { Controller } from 'stimulus';
import { fetchStatus, fetchText } from '../../lib/utils';
import $ from 'jquery';

/**
 * Controls editing and deleting tags.
 * @extends Controller
 */
export default class extends Controller {
  connect () {
    this.csrfToken = document.querySelector('[name=csrf-token]').getAttribute('content');
  }

  edit (e) {
    e.preventDefault();
    const prompt = window.prompt('What do you want to replace the “' + this.data.get('name') +  '” tag with?', this.data.get('name'));
    if (prompt.replace(/\s/g, '').length === 0 || prompt === null) {
      return;
    }
    const link = e.target;
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

  delete (e) {
    e.preventDefault();
    if (!window.confirm('Are you sure you want to delete the “' + this.data.get('name') +  '” tag?')) {
      return;
    }

    const link = e.target;
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
    .then(fetchText)
    .then(() => $(this.element).fadeOut());
  }
}
