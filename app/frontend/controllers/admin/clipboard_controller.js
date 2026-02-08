import { Controller } from '@hotwired/stimulus';

/**
 * Controls copy-to-clipboard functionality.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['source', 'button', 'icon', 'label'];

  connect () {
    this.buttonTarget.addEventListener('click', (e) => {
      e.preventDefault();
      this.copy();
    });
  }

  async copy () {
    try {
      await navigator.clipboard.writeText(this.sourceTarget.value);
      this.successfulCopy();
    } catch {
      this.unsuccessfulCopy();
    }
  }

  /**
   * Turn the button into a success message if the copy is successful
   */
  successfulCopy () {
    this.iconTarget.classList.replace('fa-clipboard', 'fa-clipboard-check');
    if (this.hasLabelTarget) {
      this.labelTarget.innerHTML = 'Copied to clipboard!';
    }
  }

  /**
   * Turn the button into an error message if the copy is unsuccessful
   */
  unsuccessfulCopy () {
    this.labelTarget.innerHTML = 'Press Ctrl+C to copy!';
  }
}
