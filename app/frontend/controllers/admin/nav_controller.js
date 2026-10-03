import { Controller } from '@hotwired/stimulus';

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
    const isActive = this.burgerTarget.classList.toggle('is-active');
    this.menuTarget.classList.toggle('is-active', isActive);
    this.burgerTarget.setAttribute('aria-expanded', String(isActive));
  }
}
