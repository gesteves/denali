import { Controller } from 'stimulus';
import $ from 'jquery';

/**
 * Controls the notifications.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['container'];

  /**
   * Opens a notification
   * @param {Event} event Custom `notify` event.
   */
  show (event) {
    const status = event.detail.status;
    const message = event.detail.message;
    const notification = $(`<div class="notification is-transparent is-${status}" data-action="click->notifications#close">
    <button class="delete"></button>
    ${message}</div>`);
    $(this.containerTarget).append(notification);
    requestAnimationFrame(() => notification[0].classList.remove('is-transparent'));
  }

  /**
   * Closes the notification
   * @param {Event} event Click event from the close button.
   */
  close (event) {
    event.currentTarget.remove();
  }
}
