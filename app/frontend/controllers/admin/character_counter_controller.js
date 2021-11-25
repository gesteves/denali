import { Controller } from 'stimulus';
import twttr from 'twitter-text';

/**
 * Updates character counts for Twitter fields.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['characterCount', 'input'];
  static values = {
    isTweet: Boolean
  }

  connect () {
    this.maxCharacters = parseInt(this.inputTarget.maxLength);
    this.updateCharacterCount();
  }

  /**
   * Count characters in the input and updates the character count.
   */
  updateCharacterCount () {
    let count;
    if (this.isTweetValue) {
      const parsedTweet = twttr.parseTweet(this.inputTarget.value);
      count = parsedTweet.weightedLength;
    } else {
      count = this.inputTarget.value.length;
    }

    this.characterCountTarget.innerHTML = count;
    if (count > (this.maxCharacters - 10)) {
      this.characterCountTarget.classList.add('has-text-danger');
    } else {
      this.characterCountTarget.classList.remove('has-text-danger');
    }
  }
}
