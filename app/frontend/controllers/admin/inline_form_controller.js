import { Controller } from '@hotwired/stimulus';

/**
 * Controls inline forms that toggle between a button and form view.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['template', 'placeholder', 'form'];
  static values = { buttonText: { type: String, default: 'Add Account' } };

  /**
   * Shows the form by replacing the placeholder with the template content.
   */
  show() {
    const content = this.templateTarget.content.cloneNode(true);
    this.placeholderTarget.replaceWith(content);
  }

  /**
   * Hides the form by replacing it with the placeholder.
   */
  hide() {
    const placeholder = document.createElement('div');
    placeholder.setAttribute('data-inline-form-target', 'placeholder');
    placeholder.innerHTML = `
      <button type="button" class="button is-info is-outlined" data-action="inline-form#show">
        ${this.buttonTextValue}
      </button>
    `;
    this.formTarget.replaceWith(placeholder);
  }
}
