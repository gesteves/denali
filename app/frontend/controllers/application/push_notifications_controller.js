import { Controller } from 'stimulus';

export default class extends Controller {
  static values = { subscribeUrl: String, vapidPublicKey: String };

  initialize() {
    if (!this.isPushSupported() || this.hasPermission()) {
      this.removeButton();
    }
  }

  isPushSupported() {
    return 'serviceWorker' in navigator && 'PushManager' in window;
  }

  hasPermission() {
    return Notification.permission === 'granted';
  }

  removeButton() {
    this.element.parentNode.removeChild(this.element);
  }

  async requestPermission(event) {
    event.preventDefault();

    try {
      const permission = await Notification.requestPermission();
      if (permission === 'granted') {
        this.subscribeUser();
        this.removeButton();
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

      this.sendSubscriptionToServer(subscription);
    } catch (error) {
      console.log(error);
    }
  }

  async sendSubscriptionToServer(subscription) {
    try {
      const response = await fetch(this.subscribeUrlValue, {
        method: 'POST',
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
