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
   * Updates the slug with the parameterized version of the title, if applicable.
   */
  handleTitleChange () {
    if (!this.isSlugEditable || this.titleTarget.value.trim() === '') {
      return;
    }

    this.slugTarget.value = this.parameterize(this.titleTarget.value);
  }

  /**
   * Determines if the slug should be modified by the title;
   * it only becomes updatable by the title if it's empty.
   * (This is so updating the title doesn't overwrite a manually-written slug.)
   */
  handleSlugChange () {
    this.isSlugEditable = this.slugTarget.value.trim() === '';
    this.handleTitleChange();
  }

  /**
   * Half-assed port of Rails `parameterize` method
   * https://www.rubydoc.info/gems/activesupport/5.0.0.1/ActiveSupport/Inflector#parameterize-instance_method
   * @param {A string} string
   * @returns string
   */
  parameterize (string) {
    const separator = '-';
    const duplicateSeparatorRegex = /-{2,}/g;
    const leadingTrailingSeparatorRegex = /^-|-$/g;
    return string.toLowerCase().replace(/[^a-z0-9\-_]+/gi, separator).replace(duplicateSeparatorRegex, separator).replace(leadingTrailingSeparatorRegex, '');
  }
}
