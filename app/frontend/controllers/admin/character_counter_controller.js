import { Controller } from 'stimulus';

/**
 * Updates character counts for text fields.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['characterCount', 'input'];

  connect () {
    this.maxCharacters = parseInt(this.inputTarget.maxLength);
    this.updateCharacterCount();
  }

  /**
   * Count characters in the input and updates the character count.
   */
  updateCharacterCount () {
    let count;
    count = this.inputTarget.value.length;

    this.characterCountTarget.innerHTML = count;
    if (count > (this.maxCharacters - 10)) {
      this.characterCountTarget.classList.add('has-text-danger');
    } else {
      this.characterCountTarget.classList.remove('has-text-danger');
    }
  }
}
