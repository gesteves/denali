import { Controller } from 'stimulus';
import $ from 'jquery';

/**
 * Controls the notifications.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['container', 'notification'];

  /**
   * Opens a notification
   * @param {Event} event Custom `notify` event.
   */
  show (event) {
    const status = event.detail.status;
    const message = event.detail.message;
    const notification = $(`<div class="notification is-${status}" data-target="notifications.notification" data-action="click->notifications#close">
    <button class="delete"></button>
    ${message}</div>`);
    if (this.notificationTargets.length === 5) {
      this.notificationTargets[0].remove();
    }
    $(this.containerTarget).append(notification);
  }

  /**
   * Closes the notification
   * @param {Event} event Click event from the close button.
   */
  close (event) {
    event.currentTarget.remove();
  }
}
