import { Controller } from 'stimulus';

/**
 * Controls setting the focal point on photos.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['focalMarker', 'focalX', 'focalY', 'thumbnail'];
  connect () {
    this.showFocalPoint();
  }

  /**
   * Positions the focal point marker on the correct position on top of the photo,
   * and displays it.
   */
  showFocalPoint () {
    if (!this.data.get('focal-x') || !this.data.get('focal-y')) {
      return;
    }

    const { offsetWidth, offsetHeight } = this.thumbnailTarget;
    this.focalMarkerTarget.style.top  = `${(offsetHeight * parseFloat(this.data.get('focal-y'))) - 50}px`;
    this.focalMarkerTarget.style.left = `${(offsetWidth  * parseFloat(this.data.get('focal-x'))) - 50}px`;
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

    this.data.set('focal-x', focalX);
    this.data.set('focal-y', focalY);
    this.focalXTarget.value = focalX;
    this.focalYTarget.value = focalY;

    this.showFocalPoint();
  }
}
