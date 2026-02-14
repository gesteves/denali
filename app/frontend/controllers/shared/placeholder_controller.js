import { Controller } from '@hotwired/stimulus';

/**
 * Removes placeholder backgrounds after the photos load.
 * @extends Controller
 */
export default class extends Controller {

  connect () {
    this.removeBackground();
  }

  disconnect () {
    if (this.onLoad) {
      this.element.removeEventListener('load', this.onLoad);
      this.onLoad = null;
    }
  }

  /**
   * Removes the backgrounds when photos load.
   * If the image is already complete, removes the placeholder immediately via rAF.
   * Otherwise, registers a one-time load listener.
   */
  removeBackground () {
    if (this.element.complete && this.element.naturalWidth > 0 && this.element.naturalHeight > 0) {
      if (this.onLoad) {
        this.element.removeEventListener('load', this.onLoad);
        this.onLoad = null;
      }
      requestAnimationFrame(() => this.element.classList.remove('placeholder'));
    } else if (!this.onLoad) {
      this.onLoad = () => this.removeBackground();
      this.element.addEventListener('load', this.onLoad, { once: true });
    }
  }
}
