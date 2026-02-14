import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';

vi.mock('../../lib/analytics', () => ({
  trackEvent: vi.fn()
}));

import PushNotificationsController from './push_notifications_controller';
import { trackEvent } from '../../lib/analytics';

describe('PushNotificationsController', () => {
  let application;
  let element;
  let mockPushManager;
  let mockSubscription;

  beforeEach(() => {
    global.fetch = vi.fn().mockResolvedValue({ ok: true });

    mockSubscription = {
      endpoint: 'https://push.example.com/subscription',
      getKey: vi.fn(() => new ArrayBuffer(0)),
      toJSON: vi.fn(() => ({
        endpoint: 'https://push.example.com/subscription',
        keys: { p256dh: 'key1', auth: 'key2' }
      })),
      unsubscribe: vi.fn(() => Promise.resolve(true))
    };

    mockPushManager = {
      getSubscription: vi.fn(() => Promise.resolve(null)),
      subscribe: vi.fn(() => Promise.resolve(mockSubscription))
    };

    const mockRegistration = {
      pushManager: mockPushManager,
      active: { state: 'activated' }
    };

    Object.defineProperty(navigator, 'serviceWorker', {
      value: {
        ready: Promise.resolve(mockRegistration)
      },
      configurable: true
    });

    global.Notification = {
      permission: 'default',
      requestPermission: vi.fn(() => Promise.resolve('granted'))
    };

    global.window.PushManager = function() {};

    document.body.innerHTML = `
      <div data-controller="push-notifications"
           data-push-notifications-endpoint-url-value="/push_subscriptions"
           data-push-notifications-vapid-public-key-value="BEl62iUYgUivxIkv69yViEuiBIa-Ib9-SkvMeAtA3LFgDzkrxZJjSgSnfckjBJuBkr3qBUYIHBQFLXYp5Nksh8U"
           data-push-notifications-text-on-value="Notifications on"
           data-push-notifications-text-off-value="Notifications off"
           data-push-notifications-text-disabled-value="Notifications blocked"
           data-push-notifications-on-class="is-primary"
           data-push-notifications-off-class="is-light"
           data-push-notifications-disabled-class="is-disabled">
        <button data-push-notifications-target="button" data-action="click->push-notifications#toggleSubscription">
          <span data-push-notifications-target="buttonText">Loading...</span>
        </button>
      </div>
    `;

    element = document.querySelector('[data-controller="push-notifications"]');
    application = Application.start();
    application.register('push-notifications', PushNotificationsController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
    vi.clearAllMocks();
  });

  function getController() {
    return application.getControllerForElementAndIdentifier(element, 'push-notifications');
  }

  function button() {
    return element.querySelector('[data-push-notifications-target="button"]');
  }

  function buttonText() {
    return element.querySelector('[data-push-notifications-target="buttonText"]');
  }

  describe('connect', () => {
    it('initializes isSubscribed to false', () => {
      const controller = getController();
      expect(controller.isSubscribed).toBe(false);
    });

    it('calls setInitialState', async () => {
      // Wait for async setInitialState to complete
      await vi.waitFor(() => {
        expect(buttonText().textContent).not.toBe('Loading...');
      });
    });
  });

  describe('setInitialState', () => {
    it('removes component when push is not supported', async () => {
      application.stop();

      // Remove PushManager to simulate unsupported browser
      delete global.window.PushManager;
      Object.defineProperty(navigator, 'serviceWorker', {
        value: undefined,
        configurable: true
      });

      document.body.innerHTML = `
        <div id="container">
          <div data-controller="push-notifications"
               data-push-notifications-endpoint-url-value="/push_subscriptions"
               data-push-notifications-vapid-public-key-value="testkey"
               data-push-notifications-text-on-value="On"
               data-push-notifications-text-off-value="Off"
               data-push-notifications-text-disabled-value="Disabled"
               data-push-notifications-on-class="is-primary"
               data-push-notifications-off-class="is-light"
               data-push-notifications-disabled-class="is-disabled">
            <button data-push-notifications-target="button">
              <span data-push-notifications-target="buttonText">Loading</span>
            </button>
          </div>
        </div>
      `;

      application = Application.start();
      application.register('push-notifications', PushNotificationsController);

      await vi.waitFor(() => {
        expect(document.querySelector('[data-controller="push-notifications"]')).toBeNull();
      });
    });

    it('sets subscribed state when user has permission and subscription exists', async () => {
      application.stop();

      global.Notification = { permission: 'granted' };
      mockPushManager.getSubscription = vi.fn(() => Promise.resolve(mockSubscription));

      application = Application.start();
      application.register('push-notifications', PushNotificationsController);

      await vi.waitFor(() => {
        expect(buttonText().textContent).toBe('Notifications on');
        expect(button().classList.contains('is-primary')).toBe(true);
      });
    });

    it('sets unsubscribed state when user has permission but no subscription', async () => {
      application.stop();

      global.Notification = { permission: 'granted' };
      mockPushManager.getSubscription = vi.fn(() => Promise.resolve(null));

      application = Application.start();
      application.register('push-notifications', PushNotificationsController);

      await vi.waitFor(() => {
        expect(buttonText().textContent).toBe('Notifications off');
        expect(button().classList.contains('is-light')).toBe(true);
      });
    });

    it('disables button when permission is denied', async () => {
      application.stop();

      global.Notification = { permission: 'denied' };

      application = Application.start();
      application.register('push-notifications', PushNotificationsController);

      await vi.waitFor(() => {
        expect(button().disabled).toBe(true);
        expect(buttonText().textContent).toBe('Notifications blocked');
        expect(button().classList.contains('is-disabled')).toBe(true);
      });
    });

    it('sets unsubscribed state when permission is default', async () => {
      await vi.waitFor(() => {
        expect(buttonText().textContent).toBe('Notifications off');
      });
    });
  });

  describe('toggleSubscription', () => {
    it('calls unsubscribeUser when already subscribed', async () => {
      const controller = getController();

      // First set to subscribed state
      global.Notification = { permission: 'granted' };
      mockPushManager.getSubscription = vi.fn(() => Promise.resolve(mockSubscription));
      await controller.setInitialState();

      expect(controller.isSubscribed).toBe(true);

      // Now toggle
      mockPushManager.getSubscription = vi.fn(() => Promise.resolve(mockSubscription));
      await controller.toggleSubscription();

      expect(mockSubscription.unsubscribe).toHaveBeenCalled();
    });

    it('calls requestPermissionAndSubscribe when not subscribed', async () => {
      const controller = getController();
      await vi.waitFor(() => expect(controller.isSubscribed).toBe(false));

      global.Notification.requestPermission = vi.fn(() => Promise.resolve('granted'));

      await controller.toggleSubscription();

      expect(global.Notification.requestPermission).toHaveBeenCalled();
    });
  });

  describe('setSubscribedState', () => {
    it('sets isSubscribed to true', () => {
      const controller = getController();
      controller.setSubscribedState();
      expect(controller.isSubscribed).toBe(true);
    });

    it('updates button text', () => {
      const controller = getController();
      controller.setSubscribedState();
      expect(buttonText().textContent).toBe('Notifications on');
    });

    it('adds on class and removes off class', () => {
      const controller = getController();
      button().classList.add('is-light');
      controller.setSubscribedState();

      expect(button().classList.contains('is-primary')).toBe(true);
      expect(button().classList.contains('is-light')).toBe(false);
    });
  });

  describe('setUnsubscribedState', () => {
    it('sets isSubscribed to false', () => {
      const controller = getController();
      controller.isSubscribed = true;
      controller.setUnsubscribedState();
      expect(controller.isSubscribed).toBe(false);
    });

    it('updates button text', () => {
      const controller = getController();
      controller.setUnsubscribedState();
      expect(buttonText().textContent).toBe('Notifications off');
    });

    it('adds off class and removes on class', () => {
      const controller = getController();
      button().classList.add('is-primary');
      controller.setUnsubscribedState();

      expect(button().classList.contains('is-light')).toBe(true);
      expect(button().classList.contains('is-primary')).toBe(false);
    });
  });

  describe('disableButton', () => {
    it('disables the button', () => {
      const controller = getController();
      controller.disableButton();
      expect(button().disabled).toBe(true);
    });

    it('removes on and off classes, adds disabled class', () => {
      const controller = getController();
      button().classList.add('is-primary', 'is-light');
      controller.disableButton();

      expect(button().classList.contains('is-disabled')).toBe(true);
      expect(button().classList.contains('is-primary')).toBe(false);
      expect(button().classList.contains('is-light')).toBe(false);
    });

    it('updates button text to disabled message', () => {
      const controller = getController();
      controller.disableButton();
      expect(buttonText().textContent).toBe('Notifications blocked');
    });
  });

  describe('isPushSupported', () => {
    it('returns true when serviceWorker and PushManager exist', () => {
      const controller = getController();
      expect(controller.isPushSupported()).toBe(true);
    });

    it('returns false when serviceWorker is missing', () => {
      const controller = getController();
      const descriptor = Object.getOwnPropertyDescriptor(navigator, 'serviceWorker');
      delete navigator.serviceWorker;
      expect(controller.isPushSupported()).toBe(false);
      Object.defineProperty(navigator, 'serviceWorker', descriptor);
    });

    it('returns false when PushManager is missing', () => {
      const controller = getController();
      const original = window.PushManager;
      delete window.PushManager;
      expect(controller.isPushSupported()).toBe(false);
      window.PushManager = original;
    });
  });

  describe('hasPermission', () => {
    it('returns true when Notification.permission is granted', () => {
      global.Notification.permission = 'granted';
      const controller = getController();
      expect(controller.hasPermission()).toBe(true);
    });

    it('returns false when Notification.permission is default', () => {
      global.Notification.permission = 'default';
      const controller = getController();
      expect(controller.hasPermission()).toBe(false);
    });

    it('returns false when Notification.permission is denied', () => {
      global.Notification.permission = 'denied';
      const controller = getController();
      expect(controller.hasPermission()).toBe(false);
    });
  });

  describe('deniedPermission', () => {
    it('returns true when Notification.permission is denied', () => {
      global.Notification.permission = 'denied';
      const controller = getController();
      expect(controller.deniedPermission()).toBe(true);
    });

    it('returns false when Notification.permission is granted', () => {
      global.Notification.permission = 'granted';
      const controller = getController();
      expect(controller.deniedPermission()).toBe(false);
    });
  });

  describe('requestPermissionAndSubscribe', () => {
    it('requests notification permission', async () => {
      const controller = getController();
      await controller.requestPermissionAndSubscribe();

      expect(global.Notification.requestPermission).toHaveBeenCalled();
    });

    it('subscribes user when permission is granted', async () => {
      const controller = getController();
      await controller.requestPermissionAndSubscribe();

      expect(mockPushManager.subscribe).toHaveBeenCalled();
    });

    it('disables button when permission is denied', async () => {
      global.Notification.requestPermission = vi.fn(() => Promise.resolve('denied'));

      const controller = getController();
      await controller.requestPermissionAndSubscribe();

      expect(button().disabled).toBe(true);
    });
  });

  describe('subscribeUser', () => {
    it('subscribes via pushManager with correct options', async () => {
      const controller = getController();
      await controller.subscribeUser();

      expect(mockPushManager.subscribe).toHaveBeenCalledWith({
        userVisibleOnly: true,
        applicationServerKey: expect.any(Uint8Array)
      });
    });

    it('sends subscription to server', async () => {
      const controller = getController();
      await controller.subscribeUser();

      expect(global.fetch).toHaveBeenCalledWith(
        '/push_subscriptions',
        expect.objectContaining({
          method: 'POST',
          headers: { 'Content-Type': 'application/json' }
        })
      );
    });

    it('sets subscribed state after success', async () => {
      const controller = getController();
      await controller.subscribeUser();

      expect(controller.isSubscribed).toBe(true);
    });
  });

  describe('unsubscribeUser', () => {
    it('unsubscribes from push manager', async () => {
      mockPushManager.getSubscription = vi.fn(() => Promise.resolve(mockSubscription));

      const controller = getController();
      controller.isSubscribed = true;
      await controller.unsubscribeUser();

      expect(mockSubscription.unsubscribe).toHaveBeenCalled();
    });

    it('sends DELETE request to server', async () => {
      mockPushManager.getSubscription = vi.fn(() => Promise.resolve(mockSubscription));

      const controller = getController();
      controller.isSubscribed = true;
      await controller.unsubscribeUser();

      expect(global.fetch).toHaveBeenCalledWith(
        '/push_subscriptions',
        expect.objectContaining({
          method: 'DELETE'
        })
      );
    });

    it('sets unsubscribed state after success', async () => {
      mockPushManager.getSubscription = vi.fn(() => Promise.resolve(mockSubscription));

      const controller = getController();
      controller.isSubscribed = true;
      await controller.unsubscribeUser();

      expect(controller.isSubscribed).toBe(false);
    });

    it('does nothing when no subscription exists', async () => {
      mockPushManager.getSubscription = vi.fn(() => Promise.resolve(null));

      const controller = getController();
      await controller.unsubscribeUser();

      expect(global.fetch).not.toHaveBeenCalled();
    });
  });

  describe('urlBase64ToUint8Array', () => {
    it('converts URL-safe base64 to Uint8Array', () => {
      const controller = getController();
      const base64 = 'SGVsbG8'; // "Hello" in base64

      const result = controller.urlBase64ToUint8Array(base64);

      expect(result).toBeInstanceOf(Uint8Array);
      expect(result.length).toBe(5); // "Hello" is 5 characters
    });

    it('handles URL-safe characters (- and _)', () => {
      const controller = getController();
      // URL-safe base64: 'abc-def_gh' should be converted to standard base64: 'abc+def/gh=='
      const urlSafeBase64 = 'abc-def_gh';
      const standardBase64 = 'abc+def/gh==';

      const urlSafeResult = controller.urlBase64ToUint8Array(urlSafeBase64);
      const standardResult = controller.urlBase64ToUint8Array(standardBase64);

      expect(urlSafeResult).toEqual(standardResult);
    });

    it('adds proper padding', () => {
      const controller = getController();
      const unpadded = 'SGVsbG8'; // Missing padding

      const result = controller.urlBase64ToUint8Array(unpadded);

      expect(result).toBeInstanceOf(Uint8Array);
    });
  });

  describe('analytics tracking', () => {
    it('tracks Subscribed event after successful subscribe', async () => {
      const controller = getController();
      await controller.subscribeUser();

      expect(trackEvent).toHaveBeenCalledWith('push-notifications', { state: 'Subscribed' });
    });

    it('tracks Unsubscribed event after successful unsubscribe', async () => {
      mockPushManager.getSubscription = vi.fn(() => Promise.resolve(mockSubscription));

      const controller = getController();
      controller.isSubscribed = true;
      await controller.unsubscribeUser();

      expect(trackEvent).toHaveBeenCalledWith('push-notifications', { state: 'Unsubscribed' });
    });

    it('does not track event when server call fails on subscribe', async () => {
      global.fetch = vi.fn().mockResolvedValue({ ok: false, status: 500 });
      trackEvent.mockClear();

      const controller = getController();
      await controller.subscribeUser();

      expect(trackEvent).not.toHaveBeenCalled();
    });

    it('does not track event when server call fails on unsubscribe', async () => {
      global.fetch = vi.fn().mockResolvedValue({ ok: false, status: 500 });
      mockPushManager.getSubscription = vi.fn(() => Promise.resolve(mockSubscription));
      trackEvent.mockClear();

      const controller = getController();
      controller.isSubscribed = true;
      await controller.unsubscribeUser();

      expect(trackEvent).not.toHaveBeenCalled();
    });
  });

  describe('error paths', () => {
    it('disables button when getSubscription rejects in setInitialState', async () => {
      application.stop();

      global.Notification = { permission: 'granted' };
      mockPushManager.getSubscription = vi.fn(() => Promise.reject(new Error('getSubscription failed')));

      document.body.innerHTML = `
        <div data-controller="push-notifications"
             data-push-notifications-endpoint-url-value="/push_subscriptions"
             data-push-notifications-vapid-public-key-value="testkey"
             data-push-notifications-text-on-value="On"
             data-push-notifications-text-off-value="Off"
             data-push-notifications-text-disabled-value="Disabled"
             data-push-notifications-on-class="is-primary"
             data-push-notifications-off-class="is-light"
             data-push-notifications-disabled-class="is-disabled">
          <button data-push-notifications-target="button">
            <span data-push-notifications-target="buttonText">Loading</span>
          </button>
        </div>
      `;

      element = document.querySelector('[data-controller="push-notifications"]');
      application = Application.start();
      application.register('push-notifications', PushNotificationsController);

      await vi.waitFor(() => {
        expect(button().disabled).toBe(true);
      });
    });

    it('stays unsubscribed when pushManager.subscribe rejects', async () => {
      mockPushManager.subscribe = vi.fn(() => Promise.reject(new Error('subscribe failed')));

      const controller = getController();
      await controller.subscribeUser();

      expect(controller.isSubscribed).toBe(false);
    });

    it('stays subscribed when subscription.unsubscribe rejects', async () => {
      mockSubscription.unsubscribe = vi.fn(() => Promise.reject(new Error('unsubscribe failed')));
      mockPushManager.getSubscription = vi.fn(() => Promise.resolve(mockSubscription));

      const controller = getController();
      controller.isSubscribed = true;
      await controller.unsubscribeUser();

      expect(controller.isSubscribed).toBe(true);
    });
  });

  describe('sendSubscriptionToServer', () => {
    it('throws when server responds with error status', async () => {
      global.fetch = vi.fn().mockResolvedValue({ ok: false, status: 500 });

      const controller = getController();
      await expect(controller.sendSubscriptionToServer(mockSubscription, 'POST'))
        .rejects.toThrow('Server responded with 500');
    });

    it('resolves when server responds with ok', async () => {
      global.fetch = vi.fn().mockResolvedValue({ ok: true });

      const controller = getController();
      await expect(controller.sendSubscriptionToServer(mockSubscription, 'POST'))
        .resolves.toBeUndefined();
    });
  });
});
