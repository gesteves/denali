import { Controller } from 'stimulus';
import ClipboardJS from 'clipboard';

/**
 * Controls copy-to-clipboard functionality.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['source', 'button', 'icon', 'label'];

  // Set up a clipboard.js instance
  connect () {
    const clipboard = new ClipboardJS(this.buttonTarget, {
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
    this.iconTarget.classList.replace('fa-clipboard', 'fa-clipboard-check');
    this.labelTarget.innerHTML = 'Copied to clipboard!';
  }

  /**
   * Turn the button into an error message if the copy is successful
   */
  unsuccessfulCopy () {
    this.labelTarget.innerHTML = 'Press Ctrl+C to copy!';
  }
}
