import { Controller } from 'stimulus';

/**
 * Controls the flash alerts.
 * @extends Controller
 */
export default class extends Controller {

  /**
   * Closes the flash alert.
   * @param {Event} event Click event from the close button.
   */
  close (event) {
    event.preventDefault();
    this.removeSelf();
  }

  /**
   * Physically removes the flash alert from the document.
   */
  removeSelf() {
    this.element.parentNode.removeChild(this.element);
  }
}
