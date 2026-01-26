import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';
import NotificationsController from './notifications_controller';

describe('NotificationsController', () => {
  let application;
  let element;

  beforeEach(() => {
    document.body.innerHTML = `
      <div data-controller="notifications" data-action="notify@document.body->notifications#add">
        <div data-notifications-target="container"></div>
      </div>
    `;

    element = document.querySelector('[data-controller="notifications"]');
    application = Application.start();
    application.register('notifications', NotificationsController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
    vi.clearAllMocks();
  });

  function getController() {
    return application.getControllerForElementAndIdentifier(element, 'notifications');
  }

  function containerTarget() {
    return element.querySelector('[data-notifications-target="container"]');
  }

  function notificationTargets() {
    return element.querySelectorAll('[data-notifications-target="notification"]');
  }

  describe('add', () => {
    it('adds notification HTML to container', () => {
      const controller = getController();
      const event = {
        detail: {
          status: 'success',
          message: 'Operation completed!'
        }
      };

      controller.add(event);

      const notifications = notificationTargets();
      expect(notifications.length).toBe(1);
      expect(notifications[0].textContent).toBe('Operation completed!');
    });

    it('applies correct status class', () => {
      const controller = getController();
      const event = {
        detail: {
          status: 'danger',
          message: 'Error occurred!'
        }
      };

      controller.add(event);

      const notification = notificationTargets()[0];
      expect(notification.classList.contains('is-danger')).toBe(true);
    });

    it('adds notification with is-transparent class initially', () => {
      const controller = getController();
      const event = {
        detail: {
          status: 'success',
          message: 'Test message'
        }
      };

      controller.add(event);

      const notification = notificationTargets()[0];
      expect(notification.classList.contains('is-transparent')).toBe(true);
    });

    it('removes is-transparent class after short delay', async () => {
      const controller = getController();
      const event = {
        detail: {
          status: 'success',
          message: 'Test message'
        }
      };

      controller.add(event);

      await new Promise(resolve => setTimeout(resolve, 20));

      const notification = notificationTargets()[0];
      expect(notification.classList.contains('is-transparent')).toBe(false);
    });

    it('closes existing notifications when adding new one', async () => {
      const controller = getController();

      // Add first notification
      controller.add({
        detail: { status: 'success', message: 'First' }
      });

      await new Promise(resolve => setTimeout(resolve, 20));

      // Add second notification
      controller.add({
        detail: { status: 'success', message: 'Second' }
      });

      const notifications = notificationTargets();
      // First notification should have closed classes
      expect(notifications[1].classList.contains('is-transparent')).toBe(true);
      expect(notifications[1].classList.contains('notification-closed')).toBe(true);
    });
  });

  describe('close', () => {
    it('adds is-transparent and notification-closed classes', async () => {
      const controller = getController();

      // Add a notification first
      controller.add({
        detail: { status: 'success', message: 'Test' }
      });

      await new Promise(resolve => setTimeout(resolve, 20));

      const notification = notificationTargets()[0];
      const event = { currentTarget: notification };

      controller.close(event);

      expect(notification.classList.contains('is-transparent')).toBe(true);
      expect(notification.classList.contains('notification-closed')).toBe(true);
    });
  });

  describe('closeAll', () => {
    it('closes all visible notifications', async () => {
      const controller = getController();

      // Add multiple notifications
      controller.add({ detail: { status: 'success', message: 'First' } });
      await new Promise(resolve => setTimeout(resolve, 20));
      controller.add({ detail: { status: 'info', message: 'Second' } });
      await new Promise(resolve => setTimeout(resolve, 20));

      // Manually call closeAll
      controller.closeAll();

      const notifications = notificationTargets();
      notifications.forEach(notification => {
        if (!notification.classList.contains('notification-closed')) {
          // The most recent notification won't be closed yet
          expect(notification.classList.contains('is-transparent')).toBe(true);
        }
      });
    });

    it('does not affect already closed notifications', async () => {
      const controller = getController();

      // Add a notification
      controller.add({ detail: { status: 'success', message: 'Test' } });
      await new Promise(resolve => setTimeout(resolve, 20));

      // Close it manually
      const notification = notificationTargets()[0];
      notification.classList.add('is-transparent', 'notification-closed');

      // Call closeAll
      controller.closeAll();

      // Should still have the classes
      expect(notification.classList.contains('is-transparent')).toBe(true);
      expect(notification.classList.contains('notification-closed')).toBe(true);
    });
  });

  describe('toggle', () => {
    it('removes notifications marked as closed when toggle is called', () => {
      const controller = getController();

      // Manually add a closed notification
      containerTarget().innerHTML = `
        <div class="notification is-success is-transparent notification-closed" data-notifications-target="notification">Old</div>
      `;

      // Call toggle manually
      controller.toggle();

      expect(notificationTargets().length).toBe(0);
    });

    it('makes transparent notifications visible when toggle is called', async () => {
      const controller = getController();

      // Manually add a transparent notification
      containerTarget().innerHTML = `
        <div class="notification is-success is-transparent" data-notifications-target="notification">New</div>
      `;

      // Call toggle manually
      controller.toggle();

      await new Promise(resolve => setTimeout(resolve, 20));

      const notification = notificationTargets()[0];
      expect(notification.classList.contains('is-transparent')).toBe(false);
    });
  });

  describe('integration', () => {
    it('handles full notification lifecycle', async () => {
      const controller = getController();

      // Add notification
      controller.add({
        detail: { status: 'success', message: 'Test message' }
      });

      let notification = notificationTargets()[0];
      expect(notification.classList.contains('is-transparent')).toBe(true);

      // After short delay, becomes visible
      await new Promise(resolve => setTimeout(resolve, 20));
      expect(notification.classList.contains('is-transparent')).toBe(false);

      // Manually close it
      notification.classList.add('is-transparent', 'notification-closed');

      // Call toggle to clean up
      controller.toggle();
      expect(notificationTargets().length).toBe(0);
    });
  });
});
