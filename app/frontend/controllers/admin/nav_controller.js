import { Controller } from 'stimulus';

/**
 * Controls the nav menu.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['burger', 'menu'];

  /**
   * Toggles the burger menu
   * @param {Event} event Click event from the burger button.
   */
  toggle (event) {
    event.preventDefault();
    this.burgerTarget.classList.toggle('is-active');
    this.menuTarget.classList.toggle('is-active');
  }
}
