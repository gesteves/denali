import { Controller } from 'stimulus';

/**
 * Controls the native share options.
 * @extends Controller
 */
export default class extends Controller {

  connect () {
    if (!navigator.share) {
      this.element.remove();
    }
  }

  /**
   * Opens the native share pane
   * @param {Event} event Click event from the share button.
   */
  open (event) {
    event.preventDefault();
    navigator.share({
      url: this.data.get('url'),
    });
  }
}
