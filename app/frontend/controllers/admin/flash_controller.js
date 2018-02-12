import { Controller } from 'stimulus';

/**
 * Controls the flash alerts.
 * @extends Controller
 */
export default class extends Controller {

  /**
   * Sets up a timeout so flash alerts are dismissed automatically after a period
   * of time.
   */
  connect () {
    this.timeout_id = setTimeout(() => this.removeSelf(), parseInt(this.data.get('timeout')));
  }

  /**
   * Closes the flash aler.
   * @param {Event} event Click event from the close button.
   */
  close (event) {
    event.preventDefault();
    this.removeSelf();
    clearTimeout(this.timeout_id);
  }

  /**
   * Physically removes the flash alert from the document.
   */
  removeSelf() {
    this.element.parentNode.removeChild(this.element);
  }
}
