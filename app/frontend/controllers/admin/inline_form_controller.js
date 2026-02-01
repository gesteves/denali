import { Controller } from '@hotwired/stimulus';

/**
 * Controls inline forms that toggle between a button and form view.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['template', 'placeholder', 'form'];

  /**
   * Shows the form by replacing the placeholder with the template content.
   */
  show() {
    this.savedPlaceholder = this.placeholderTarget.cloneNode(true);
    const content = this.templateTarget.content.cloneNode(true);
    this.placeholderTarget.replaceWith(content);
  }

  /**
   * Hides the form by replacing it with the placeholder.
   */
  hide() {
    this.formTarget.replaceWith(this.savedPlaceholder);
  }
}
