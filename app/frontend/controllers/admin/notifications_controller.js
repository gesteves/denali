import { Controller } from 'stimulus';
import $ from 'jquery';

/**
 * Controls the notifications.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['container', 'notification'];

  connect () {
    this.toggle();
  }

  /**
   * Opens a notification
   * @param {Event} event Custom `notify` event.
   */
  show (event) {
    const status = event.detail.status;
    const message = event.detail.message;
    const notification = $(`<div class="notification is-${status} is-transparent" data-target="notifications.notification" data-action="click->notifications#close">
    <button class="delete"></button>
    ${message}</div>`);
    if (this.hasNotificationTarget) {
      this.closeAll();
      $(this.containerTarget).prepend(notification);
    } else {
      $(this.containerTarget).prepend(notification);
      this.toggle();
    }
  }

  /**
   * Hides all the existing notifications on the page.
   */
  closeAll () {
    this.notificationTargets
      .filter(notification => !notification.classList.contains('is-transparent'))
      .forEach(notification => {
        notification.classList.add('is-transparent', 'notification-closed');
      });
  }

  /**
   * Closes the notification
   * @param {Event} event Click event from the close button.
   */
  close (event) {
    event.currentTarget.classList.add('is-transparent', 'notification-closed');
  }

  /**
   * Removes all notifications that have been marked as closed from the DOM,
   * and displays any pending transparent notifications.
   * @param {Event} event Click event from the close button.
   */
  toggle () {
    this.notificationTargets
      .filter(notification => notification.classList.contains('notification-closed'))
      .forEach(notification => notification.remove());
    this.notificationTargets
      .forEach(notification => {
        setTimeout(() => notification.classList.remove('is-transparent'), 10);
        setTimeout(() => notification.classList.add('is-transparent', 'notification-closed'), 10000);
      });
  }
}
