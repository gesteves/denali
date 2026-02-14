import { Controller } from '@hotwired/stimulus';

/**
 * Controls the notifications.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['container', 'notification'];

  connect () {
    this.timeouts = [];
    this.toggle();
  }

  disconnect () {
    this.timeouts.forEach(id => clearTimeout(id));
    this.timeouts = [];
  }

  /**
   * Called when a notification target is connected (e.g., via Turbo Stream).
   * @param {Element} target The newly connected notification element.
   */
  notificationTargetConnected (target) {
    this.timeouts.push(setTimeout(() => target.classList.remove('is-transparent'), 10));
    this.timeouts.push(setTimeout(() => target.classList.add('is-transparent', 'notification-closed'), 10000));
  }

  /**
   * Adds a new notification to the notifications container
   * @param {Event} event Custom `notify` event.
   */
  add (event) {
    const status = event.detail.status;
    const message = event.detail.message;
    const notificationHtml = `<div class="notification is-${status} is-transparent" data-notifications-target="notification" data-action="click->notifications#close">${message}</div>`;
    if (this.hasNotificationTarget) {
      this.closeAll();
      this.containerTarget.insertAdjacentHTML('afterbegin', notificationHtml);
    } else {
      this.containerTarget.insertAdjacentHTML('afterbegin', notificationHtml);
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
        this.timeouts.push(setTimeout(() => notification.classList.remove('is-transparent'), 10));
        this.timeouts.push(setTimeout(() => notification.classList.add('is-transparent', 'notification-closed'), 10000));
      });
  }
}
