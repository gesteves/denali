import { Controller } from 'stimulus';

/**
 * Removes Blurhash backgrounds after the photos load.
 * @extends Controller
 */
export default class extends Controller {

  connect () {
    this.removeBackground();
  }

  /**
   * Removes the backgrounds when photos load.
   * Uses a setInterval to give the real photo a chance to render
   * before removing the background, to prevent annoying flashing.
   */
  removeBackground () {
    const interval = setInterval(() => {
      if (this.element.complete && this.element.naturalWidth > 0 && this.element.naturalHeight > 0) {
        clearInterval(interval);
        requestAnimationFrame(() => this.element.classList.remove('blurhash'));
      }
    }, 1000);
  }
}
