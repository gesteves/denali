import { Controller } from 'stimulus';

export default class extends Controller {
  static targets = ['checkbox', 'message'];
  static values = { endpointUrl: String, vapidPublicKey: String };

  connect() {
    this.setInitialState();
  }

  async setInitialState() {
    if (!this.isPushSupported()) {
      this.disableCheckbox('Your browser doesn’t support push notifications');
    } else if (this.hasPermission()) {
      const registration = await navigator.serviceWorker.ready;
      const subscription = await registration.pushManager.getSubscription();

      if (subscription) {
        this.checkboxTarget.checked = true;
      } else {
        this.checkboxTarget.checked = false;
      }
    } else if (this.deniedPermission()) {
      this.disableCheckbox('Notifications are disabled for this website in your browser settings');
    } else {
      this.checkboxTarget.checked = false;
    }
  }

  async toggleSubscription() {
    if (this.checkboxTarget.checked) {
      await this.requestPermissionAndSubscribe();
    } else {
      await this.unsubscribeUser();
    }
  }

  disableCheckbox(message) {
    this.checkboxTarget.checked = false;
    this.checkboxTarget.disabled = true;
    this.messageTarget.classList.remove('push-notifications__message--hidden')
    this.messageTarget.innerText = message;
  }

  isPushSupported() {
    return 'serviceWorker' in navigator && 'PushManager' in window;
  }

  hasPermission() {
    return Notification.permission === 'granted';
  }

  deniedPermission() {
    return Notification.permission === 'denied';
  }

  async requestPermissionAndSubscribe() {
    try {
      const permission = await Notification.requestPermission();
      if (permission === 'granted') {
        this.subscribeUser();
      } else {
        this.disableCheckbox('Notifications are disabled for this website in your browser settings');
      }
    } catch (error) {
      console.log(error);
    }
  }

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
