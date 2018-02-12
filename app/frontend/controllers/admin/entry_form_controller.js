import { Controller } from 'stimulus';
import { fetchStatus, fetchText } from '../../lib/utils';
import $ from 'jquery';
import { Sortable } from '@shopify/draggable';
import Awesomplete from 'awesomplete';
/**
 * Controls the entry form.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['photos', 'tags'];

  connect () {
    new Awesomplete(this.tagsTarget, {
      list: '#datalist-tags',
      filter: function (text, input) {
        return Awesomplete.FILTER_CONTAINS(text, input.match(/[^,]*$/)[0]);
      },
      replace: function (text) {
        var before = this.input.value.match(/^.+,\s*|/)[0];
        this.input.value = before + text + ', ';
      }
    });

    new Sortable(this.photosTarget, {
      draggable: 'li',
      delay: 100,
      classes: {
        'source:dragging': 'form__photo--dragging',
        'mirror': 'form__photo--mirror'
      }
    });
  }

  addPhoto (e) {
    e.preventDefault();
    const url = this.data.get('photo-endpoint');

    const fetchOpts = {
      method: 'GET',
      headers: new Headers({
        'X-CSRF-Token': this.csrfToken
      }),
      credentials: 'include'
    };

    fetch(`${url}`, fetchOpts)
    .then(fetchStatus)
    .then(fetchText)
    .then(html => $(this.photosTarget).append(html));
  }

  submit (e) {
    e.preventDefault();
    this.element.querySelectorAll('[data-position]').forEach((e, i) => {
      e.value = i + 1;
    });
    e.target.submit();
  }
}
