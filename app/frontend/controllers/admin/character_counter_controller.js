import { Controller } from '@hotwired/stimulus';
import { render } from '../../lib/markdown_links';
import { apply } from '../../lib/typography';

/**
 * Updates character counts for text fields, accounting for Markdown syntax and Unicode graphemes.
 *
 * ⚠️ It counts what the POST will hold, not what the author typed, because that is what Bluesky
 * measures: the address of a Markdown link lives in a facet, so `[my post](https://example.com)`
 * is 7 characters and not 30. The count disables the submit button, so counting the raw words
 * would refuse a draft that Bluesky accepts.
 *
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['characterCount', 'input', 'submit'];
  static values = {
    maxLength: Number
  }

  connect () {
    this.maxCharacters = this.hasMaxLengthValue ? this.maxLengthValue : parseInt(this.inputTarget.maxLength, 10);
    this.updateCharacterCount();
  }

  /**
   * Count characters in the input and updates the character count.
   */
  updateCharacterCount () {
    const plainText = this.stripMarkdown(this.inputTarget.value);
    const segmenter = new Intl.Segmenter('en', { granularity: 'grapheme' });
    const count = [...segmenter.segment(plainText)].length;

    this.characterCountTarget.innerHTML = count;
    if (count > (this.maxCharacters - 10)) {
      this.characterCountTarget.classList.add('has-text-danger');
    } else {
      this.characterCountTarget.classList.remove('has-text-danger');
    }

    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = count > this.maxCharacters;
    }
  }

  /**
   * Renders the text the way the post will hold it.
   *
   * ⚠️ The order matches the server: typography first, then the link grammar.
   *
   * @param {string} text - The input text containing Markdown.
   * @returns {string} - The plain text the post will hold.
   */
  stripMarkdown (text) {
    return render(apply(text));
  }
}
