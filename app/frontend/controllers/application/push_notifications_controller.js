import { Controller } from 'stimulus';

export default class extends Controller {
  static targets = ['checkbox', 'label'];
  static values = { endpointUrl: String, vapidPublicKey: String };

  connect() {
    this.setInitialState();
  }

  /**
   * Sets the initial state of the push notifications checkbox.
   */
  async setInitialState() {
    if (!this.isPushSupported()) {
      this.removeComponent();
    } else if (this.hasPermission()) {
      const registration = await navigator.serviceWorker.ready;
      const subscription = await registration.pushManager.getSubscription();

      if (subscription) {
        this.checkboxTarget.checked = true;
      } else {
        this.checkboxTarget.checked = false;
      }
    } else if (this.deniedPermission()) {
      this.disableCheckbox();
    } else {
      this.checkboxTarget.checked = false;
    }
  }

  /**
   * Toggles the push notification subscription state based on the checkbox.
   * @returns {Promise}
   */
  async toggleSubscription() {
    if (this.checkboxTarget.checked) {
      await this.requestPermissionAndSubscribe();
    } else {
      await this.unsubscribeUser();
    }
  }

  /**
   * Removes the entire component from the DOM.
   */
  removeComponent() {
    this.element.parentNode.removeChild(this.element);
  }

  /**
   * Disables the checkbox and adds a disabled style to the label.
   */
  disableCheckbox() {
    this.checkboxTarget.checked = false;
    this.checkboxTarget.disabled = true;
    this.labelTarget.classList.add('push-notifications__label--disabled');
  }

  /**
   * Checks if the browser supports push notifications.
   * @returns {boolean}
   */
  isPushSupported() {
    return 'serviceWorker' in navigator && 'PushManager' in window;
  }

  /**
   * Checks if the user has granted permission for push notifications.
   * @returns {boolean}
   */
  hasPermission() {
    return Notification.permission === 'granted';
  }

  /**
   * Checks if the user has denied permission for push notifications.
   * @returns {boolean}
   */
  deniedPermission() {
    return Notification.permission === 'denied';
  }

  /**
   * Requests permission for push notifications and subscribes the user if granted.
   * @returns {Promise}
   */
  async requestPermissionAndSubscribe() {
    try {
      const permission = await Notification.requestPermission();
      if (permission === 'granted') {
        this.subscribeUser();
      } else {
        this.disableCheckbox();
      }
    } catch (error) {
      console.log(error);
    }
  }

  /**
   * Subscribes the user to push notifications and sends the subscription to the server.
   * @returns {Promise}
   */
  async subscribeUser() {
    try {
      const registration = await navigator.serviceWorker.ready;
      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: this.urlBase64ToUint8Array(this.vapidPublicKeyValue)
      });

      this.sendSubscriptionToServer(subscription, 'POST');
    } catch (error) {
      console.log(error);
    }
  }

  /**
 * Unsubscribes the user from push notifications and deletes the subscription from the server.
 * @returns {Promise}
 */
  async unsubscribeUser() {
    try {
      const registration = await navigator.serviceWorker.ready;
      const subscription = await registration.pushManager.getSubscription();

      if (subscription) {
        await subscription.unsubscribe();
        this.sendSubscriptionToServer(subscription, 'DELETE');
      }
    } catch (error) {
      console.log(error);
    }
  }

  /**
   * Sends the push notification subscription to the server with the specified method (POST or DELETE).
   * @param {PushSubscription} subscription - The push notification subscription.
   * @param {string} method - The HTTP method to use (POST or DELETE).
   * @returns {Promise}
   */
  async sendSubscriptionToServer(subscription, method) {
    try {
      const response = await fetch(this.endpointUrlValue, {
        method: method,
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(subscription)
      });
    } catch (error) {
      console.log(error);
    }
  }

  /**
   * Converts a URL-safe base64 string to a Uint8Array.
   * @param {string} base64String - The URL-safe base64 string to convert.
   * @returns {Uint8Array} - The resulting Uint8Array.
   */
  urlBase64ToUint8Array(base64String) {
    const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
    const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');

    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);

    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  }  
}
