import { Controller } from 'stimulus';
import { fetchStatus, fetchText } from '../../lib/utils';
import $ from 'jquery';

/**
 * Controls setting the focal point on photos.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['focalMarker', 'focalX', 'focalY', 'thumbnail', 'responseContainer'];
  static values = {
    focalX: Number,
    focalY: Number,
    endpoint: String
  }

  connect () {
    this.showFocalPoint();
    this.csrfToken = document.querySelector('[name=csrf-token]').getAttribute('content');
  }

  /**
   * Positions the focal point marker on the correct position on top of the photo,
   * and displays it.
   */
  showFocalPoint () {
    if (!this.hasFocalXValue || !this.hasFocalYValue) {
      return;
    }

    const { offsetWidth, offsetHeight } = this.thumbnailTarget;
    this.focalMarkerTarget.style.top  = `${(offsetHeight * this.focalYValue) - 50}px`;
    this.focalMarkerTarget.style.left = `${(offsetWidth  * this.focalXValue) - 50}px`;
    this.focalMarkerTarget.classList.remove('is-hidden');
  }

  /**
   * Calculates the focal point for the photo based on where the user clicked on
   * the thumbnail.
   * @param {Event} event A click event from the photo's thumbnail.
   */
  setFocalPoint (event) {
    event.preventDefault();
    const { top, left } = this.thumbnailTarget.getBoundingClientRect();
    const { offsetWidth, offsetHeight} = this.thumbnailTarget;
    const focalX = (event.pageX - (window.scrollX + left))/offsetWidth;
    const focalY = (event.pageY - (window.scrollY + top))/offsetHeight;

    this.focalXValue = focalX;
    this.focalYValue = focalY;
    if (this.hasFocalXTarget) {
      this.focalXTarget.value = focalX;
    }
    if (this.hasFocalYTarget) {
      this.focalYTarget.value = focalY;
    }
    if (this.hasEndpointValue) {
      this.updateFocalPoint();
    }

    this.showFocalPoint();
  }

  /**
   * Updates the focal point and inserts the result into the container
   * TODO: Remove the jQuery dependency.
   */
  updateFocalPoint () {
    event.preventDefault();
    let formData = new FormData();

    formData.append('photo[focal_x]', this.focalXValue);
    formData.append('photo[focal_y]', this.focalYValue);

    const fetchOpts = {
      method: 'POST',
      headers: new Headers({
        'X-CSRF-Token': this.csrfToken
      }),
      credentials: 'include',
      body: formData
    };

    fetch(this.endpointValue, fetchOpts)
      .then(fetchStatus)
      .then(fetchText)
      .then(html => $(this.responseContainerTarget).html(html));
  }
}
