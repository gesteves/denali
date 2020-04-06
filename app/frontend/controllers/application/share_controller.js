import { Controller } from 'stimulus';
import { trackEvent } from '../../lib/analytics';

/**
 * Controls the native share options.
 * @extends Controller
 */
export default class extends Controller {

  connect () {
    if (navigator.share) {
      this.element.classList.remove('share--hidden');
      document.body.classList.add('has-share-button');
    } else {
      this.element.remove();
    }
  }

  /**
   * Opens the native share pane
   * @param {Event} event Click event from the share button.
   */
  open (event) {
    event.preventDefault();
    event.stopPropagation();
    navigator.share({
      url: this.element.href,
    }).then(() => { trackEvent(this.element.href, 'share:success', 'click'); }).catch(() => { trackEvent(this.element.href, 'share:cancel', 'click'); });
  }
}
