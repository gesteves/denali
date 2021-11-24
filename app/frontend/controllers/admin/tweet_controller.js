import { Controller } from 'stimulus';
import twttr from 'twitter-text';

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
    const parsedTweet = twttr.parseTweet(this.inputTarget.value);
    let count = parsedTweet.weightedLength;
    this.characterCountTarget.innerHTML = count;
    if (count > 220) {
      this.characterCountTarget.classList.add('has-text-danger');
    } else {
      this.characterCountTarget.classList.remove('has-text-danger');
    }
  }
}
