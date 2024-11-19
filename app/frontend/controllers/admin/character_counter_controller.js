import { Controller } from 'stimulus';
import GraphemeSplitter from 'grapheme-splitter';

/**
 * Updates character counts for text fields, accounting for Markdown syntax and Unicode graphemes.
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
    const splitter = new GraphemeSplitter();
    const processedText = this.stripMarkdown(this.inputTarget.value); // Strip Markdown
    const graphemes = splitter.splitGraphemes(processedText); // Count Unicode graphemes

    const count = graphemes.length;

    this.characterCountTarget.innerHTML = count;
    if (count > (this.maxCharacters - 10)) {
      this.characterCountTarget.classList.add('has-text-danger');
    } else {
      this.characterCountTarget.classList.remove('has-text-danger');
    }
  }

  /**
   * Strips Markdown syntax from the text, leaving only the plain text.
   * For example, [X](https://www.example.com) becomes X.
   * @param {string} text - The input text containing Markdown.
   * @returns {string} - The plain text with Markdown stripped.
   */
  stripMarkdown (text) {
    // Replace Markdown links [label](url) with just the label
    return text.replace(/\[([^\]]+)\]\([^)]+\)/g, '$1');
  }
}
