import { Controller } from 'stimulus';

/**
 * Controls the notifications.
 * @extends Controller
 */
export default class extends Controller {

  /**
   * Closes the notification
   * @param {Event} event Click event from the close button.
   */
  close (event) {
    event.preventDefault();
    this.element.remove();
  }
}
