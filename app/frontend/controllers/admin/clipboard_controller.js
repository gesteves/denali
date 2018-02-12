import { Controller } from 'stimulus';

/**
 * Controls copy-to-clipboard functionality.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['source'];

  /**
   * Copies the target's contents to the clipboard.
   * @param {Event} event A click event from the copy button.
   */
  copy (event) {
    event.preventDefault();
    this.sourceTarget.select();
    const copied = document.execCommand('copy');
    this.sourceTarget.setSelectionRange(0,0);
    if (copied) {
      event.target.innerHTML = 'Copied to clipboard!';
    } else {
      event.target.innerHTML = 'Whoops, something went wrong ¯\\_(ツ)_/¯';
    }
  }
}
