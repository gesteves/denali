import { Controller } from 'stimulus';

/**
 * Updates slugs for entries.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['slug', 'title'];

  connect () {
    this.handleSlugChange();
  }

  /**
   * Count characters in the input and updates the character count.
   */
  handleTitleChange () {
    if (!this.isSlugEditable || this.titleTarget.value.trim() === '') {
      return;
    }

    this.slugTarget.value = this.parameterize(this.titleTarget.value);
  }

  handleSlugChange () {
    this.isSlugEditable = this.slugTarget.value.trim() === '';
    this.handleTitleChange();
  }

  parameterize (string) {
    const separator = '-';
    const duplicateSeparatorRegex = /-{2,}/g;
    const leadingTrailingSeparatorRegex = /^-|-$/g;
    return string.toLowerCase().replace(/[^a-z0-9\-_]+/gi, separator).replace(duplicateSeparatorRegex, separator).replace(leadingTrailingSeparatorRegex, '');
  }
}
