import { Controller } from 'stimulus';

/**
 * Removes Blurhash backgrounds after the photos load.
 * Uses RAF to try to ensure the background only gets removed
 * after the real image is rendered, to avoid annoying flashes.
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
    requestAnimationFrame(() => this.element.classList.remove('blurhash'));
  }

  imageLoaded () {
    requestAnimationFrame(() => this.startRender());
  }

  startRender () {
    requestAnimationFrame(() => this.removeBackground());
  }
}
