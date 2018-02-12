import { Controller } from 'stimulus';

/**
 * Controls copy-to-clipboard functionality.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['source'];

  /**
   * Copies the target's contents to the clipboard.
   * @param {Event} e A click event from the copy button.
   */
  copy (e) {
    e.preventDefault();
    this.sourceTarget.select();
    const copied = document.execCommand('copy');
    this.sourceTarget.setSelectionRange(0,0);
    if (copied) {
      e.target.innerHTML = 'Copied to clipboard!';
    } else {
      e.target.innerHTML = "Whoops, something went wrong ¯\_(ツ)_/¯";
    }
  }
}
