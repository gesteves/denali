import { Controller } from 'stimulus';

/**
 * Controls the flash alerts.
 * @extends Controller
 */
export default class extends Controller {
  connect () {
    this.timeout_id = setTimeout(() => this.removeSelf(), parseInt(this.data.get('timeout')));
  }

  close (e) {
    e.preventDefault();
    this.removeSelf();
    clearTimeout(this.timeout_id);
  }

  removeSelf() {
    this.element.parentNode.removeChild(this.element);
  }
}
