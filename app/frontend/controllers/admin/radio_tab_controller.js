import { Controller } from 'stimulus';

/**
 * Controls the radio tabs in forms.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['tab', 'field'];

  /**
   * Toggles the active tab
   * @param {Event} event Click event from the tab.
   */
  toggle (event) {
    event.preventDefault();
    const tab =  event.currentTarget;

    if (tab.classList.contains('is-active')) {
      return false;
    }
    this.tabTargets.forEach(tab => {
      tab.classList.remove('is-active');
    });
    tab.classList.add('is-active');

    this.fieldTarget.value = tab.getAttribute('data-radio-tab-value');
  }
}
