import { Controller } from 'stimulus';

/**
 * Controls the dropdown menus.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['icon'];

  /**
   * Toggles the dropdown menu
   * @param {Event} event Click event from the dropdown button.
   */
  toggle (event) {
    event.preventDefault();
    this.element.classList.toggle('is-active');
    this.iconTarget.classList.toggle('fa-angle-up');
    this.iconTarget.classList.toggle('fa-angle-down');
  }
}
