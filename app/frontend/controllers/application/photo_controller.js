import { Controller } from 'stimulus';

/**
 * Controls the ability to zoom in on photos. Checks their dimensions to decide
 * if they can be zoomed in, depending on their size and the size of the viewport.
 * TODO: Turn this into a lightbox, rather than enlarging the images.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['photo'];

  connect () {
    this.photoTargets.forEach(p => this.checkIfZoomable(p));
  }

  /**
   * Checks if an image is zoomable, and adds the appropriate CSS classes to make
   * it so. Images are sized to fit the viewport; an image is zoomable if it would
   * be taller than the viewport if rendered at full size.
   * @param  {Element} photo The photo's <img> element.
   */
  checkIfZoomable (photo) {
    // Get the viewport dimensions.
    const { clientWidth, clientHeight } = document.documentElement;

    // Get the full size of the original photo
    const originalHeight = parseInt(photo.getAttribute('height'));
    const originalWidth = parseInt(photo.getAttribute('width'));

    // Get the max width this photo can be rendered at; it is the smallest of:
    // `originalWidth`     (it can't be wider than the original)
    // `clientWidth`       (it can't be wider than the viewport)
    // `containerMaxWidth` (it can't be wider than the max width of its container)
    const maxWidth = Math.min(originalWidth, clientWidth, parseInt(this.data.get('containerMaxWidth')));

    // Based on this `maxWidth`, calculate how tall the image would be if rendered
    // at that width.
    const imageRatio = originalHeight/originalWidth;
    const height = maxWidth * imageRatio;

    // If it'd be taller than the viewport, then it is zoomable.
    if (height > clientHeight) {
      photo.classList.add('entry__photo--zoomable');
      photo.setAttribute('data-photo-zoomable', 1);
    }
  }

  /**
   * Click handler that zooms in all zoomable images on the page.
   */
  zoom () {
    this.photoTargets.forEach(photo => {
      if (photo.getAttribute('data-photo-zoomable') === '1') {
        photo.classList.toggle('entry__photo--zoom');
      }
    });
  }
}
