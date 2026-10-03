import { Controller } from '@hotwired/stimulus';
import { supportsHover } from '../../lib/utils';

/**
 * Controls the dropdown menus.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['trigger'];

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
      this.updateExpanded();
    }
  }

  /**
   * Closes the dropdown menu
   * @param {Event} event Click event from the document.
   */
  close () {
    if (!this.isHoverable) {
      this.element.classList.remove('is-active');
      this.updateExpanded();
    }
  }

  /**
   * Mirrors the menu's state on its trigger, for screen readers.
   */
  updateExpanded () {
    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute('aria-expanded', String(this.element.classList.contains('is-active')));
    }
  }
}
