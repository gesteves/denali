import { Controller } from 'stimulus';
import Clipboard from 'clipboard';

/**
 * Controls copy-to-clipboard functionality.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['source', 'button'];

  // Set up a clipboard.js instance
  connect () {
    const clipboard = new Clipboard(this.buttonTarget, {
      target: () => this.sourceTarget
    });
    clipboard.on('success', e => this.successfulCopy(e));
    clipboard.on('error',   e => this.unsuccessfulCopy(e));
  }

  /**
   * Convenience method to stop the button from doing its thing.
   * @param  {Event} event Click event from the button.
   */
  preventDefault (event) {
    event.preventDefault();
  }

  /**
   * Turn the button into a success message if the copy is successful
   * @param  {Event} event Success event from the clipboard instance.
   */
  successfulCopy (event) {
    event.clearSelection();
    this.buttonTarget.innerHTML = 'Copied to clipboard!';
  }

  /**
   * Turn the button into an error message if the copy is successful
   * @param  {Event} event Error event from the clipboard instance.
   */
  unsuccessfulCopy (event) {
    this.buttonTarget.innerHTML = 'Press Ctrl+C to copy!';
  }
}
