import { Controller } from 'stimulus';
import { supportsHover } from '../../lib/utils';

/**
 * Controls the dropdown menus.
 * @extends Controller
 */
export default class extends Controller {

  connect () {
    this.isHoverable = supportsHover();
    if (this.isHoverable) {
      this.element.classList.add('is-hoverable');
    }
  }

  /**
   * Toggles the dropdown menu
   * @param {Event} event Click event from the dropdown button.
   */
  toggle (event) {
    event.preventDefault();
    event.stopPropagation();
    if (!this.isHoverable) {
      if (!this.element.classList.contains('is-active')) {
        document.dispatchEvent(new CustomEvent('closeDropdowns'));
      }
      this.element.classList.toggle('is-active');
    }
  }

  /**
   * Closes the dropdown menu
   * @param {Event} event Click event from the document.
   */
  close () {
    if (!this.isHoverable) {
      this.element.classList.remove('is-active');
    }
  }
}
