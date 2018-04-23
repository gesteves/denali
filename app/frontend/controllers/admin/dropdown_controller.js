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
    if (!this.isHoverable) {
      this.element.classList.toggle('is-active');
    }
  }
}
