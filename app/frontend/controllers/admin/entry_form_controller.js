import { Controller } from 'stimulus';
import { fetchStatus, fetchText } from '../../lib/utils';
import $ from 'jquery';
import { Sortable, Plugins } from '@shopify/draggable';

/**
 * Controls the entry form.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['photos'];

  /**
   * Sets up the drag-and-drop of photos.
   */
  connect () {
    this.sortablePhotos = new Sortable(this.photosTarget, {
      delay: 100,
      classes: {
        'source:dragging': 'draggable-dragging',
        'mirror': 'draggable-mirror'
      },
      handle: '.draggable-handle',
      plugins: [Plugins.SwapAnimation]
    });

    this.sortablePhotos.on('drag:start', event => this.startSort(event));
  }

  /**
   * Fetches a new set of fields to add another photo to the entry,
   * add appends it to the form.
   * TODO: Remove jQuery dependency.
   * @param {Event} event A click event from the add photo button.
   */
  addPhoto (event) {
    event.preventDefault();
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

  /**
   * Handles the start of a sorting event, hardcoding the size of the dragged
   * element so it doesn't look weird while being dragged.
   * Sortable events docs: https://github.com/Shopify/draggable/tree/master/src/Sortable/SortableEvent
   * @param {Event} event A sortable:start event.
   */
  startSort (event) {
    let mirror = event.data.mirror;
    let originalWidth = event.data.source.clientWidth;
    mirror.style.width = `${originalWidth}px`;
  }

  /**
   * Updates all the position fields on the photos before submitting the form,
   * setting them to their order in the DOM (which may change due to drag and drop).
   * @param {Event} event A submit event from the form.
   */
  submit (event) {
    event.preventDefault();
    this.element.querySelectorAll('[data-position]').forEach((element, index) => {
      element.value = index + 1;
    });
    event.target.submit();
  }
}
