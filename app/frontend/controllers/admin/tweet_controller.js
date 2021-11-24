import { Controller } from 'stimulus';

/**
 * Updates character counts for Twitter fields.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['characterCount', 'input'];

  connect () {
    this.updateCharacterCount();
  }

  /**
   * Count characters in the input and updates the character count.
   */
  updateCharacterCount () {
    var count = this.inputTarget.value.length;
    this.characterCountTarget.innerHTML = count;
    if (count > 220) {
      this.characterCountTarget.classList.add('has-text-danger');
    } else {
      this.characterCountTarget.classList.remove('has-text-danger');
    }
  }
}
