import 'intersection-observer';
import { fetchStatus, fetchText } from '../../lib/utils';
import { Controller }             from 'stimulus';

/**
 * Controls the lazy loading of related entries.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['spinner'];

  connect () {
    this.spinnerTarget.classList.add('loading--active');
    this.element.classList.add('entry__related');
    // Set up an intersection observer to observe the sentinel element.
    this.observer = new IntersectionObserver(e => this.handleIntersect(e), { rootMargin: '50%' });
    this.observer.observe(this.spinnerTarget);
    // Enable polling on the polyfill to work around some Safari weirdness
    this.observer.POLL_INTERVAL = 50;
  }

  /**
   * Handler for the intersection observer that observes the sentinel at the
   * bottom of the page. If it's visible, loads the related entries.
   * @param {IntersectionObserverEntry[]} entries An array of intersection observer entries
   */
  handleIntersect (entries) {
    if (!entries.filter(entry => {
      return (entry.intersectionRatio > 0 || entry.isIntersecting);
    }).length) {
      return;
    }
    fetch(this.data.get('url'), { credentials: 'same-origin' })
      .then(fetchStatus)
      .then(fetchText)
      .then(text => {
        this.appendEntries(text);
      })
      .catch(() => this.endObserver());
  }

  /**
   * Creates an HTML fragment from a string of markup, replaces the element..
   * @param {string} html The html to be inserted into the DOM
   */
  appendEntries (html) {
    if (!html) {
      this.endObserver();
      return;
    }
    const fragment = document.createRange().createContextualFragment(html);
    this.observer.unobserve(this.spinnerTarget);
    this.element.parentNode.replaceChild(fragment, this.element);
  }

  /**
   * If there are no entries to be fetched, unobserves the sentinel,
   * and removes it from the page.
   */
  endObserver () {
    this.observer.unobserve(this.spinnerTarget);
    this.element.parentNode.removeChild(this.element);
  }
}
