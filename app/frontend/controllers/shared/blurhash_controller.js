import { Controller } from 'stimulus';

/**
 * Removes Blurhash backgrounds after the photos load.
 * @extends Controller
 */
export default class extends Controller {

  connect () {
    if (this.element.complete && this.element.naturalWidth > 0 && this.element.naturalHeight > 0) {
      requestAnimationFrame(() => this.removeBackground());
    }
  }

  /**
   * Removes the backgrounds when photos load.
   */
  removeBackground () {
    this.element.classList.remove('blurhash');
  }

  imageLoaded () {
    requestAnimationFrame(() => this.startRender());
  }

  startRender () {
    requestAnimationFrame(() => this.removeBackground());
  }
}
