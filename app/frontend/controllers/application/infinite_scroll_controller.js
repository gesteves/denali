import 'intersection-observer';
import { fetchStatus, fetchText } from '../../lib/utils';
import { Controller }             from 'stimulus';

/**
 * Controls the infinite loading of entries on the
 * entries#index and entries#tagged views.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['container', 'paginator', 'spinner'];

  connect () {
    // If there's no loading spinner, there's nothing to observe.
    // If there's no paginator, it means there are no more pages to load.
    // In either of these cases, return early.
    if (!this.hasSpinnerTarget || !this.hasPaginatorTarget) {
      return;
    }

    this.preparePage();

    // Set up an intersection observer to observe the loading spinner at the bottom.
    // When it's in view, fetch the next page.
    this.observer = new IntersectionObserver(e => this.handleIntersect(e), { rootMargin: '50%' });
    this.observer.observe(this.spinnerTarget);
    // Enable polling on the polyfill to work around some Safari weirdness
    this.observer.POLL_INTERVAL = 50;
  }

  /**
   * Getter for the current page
   * @return {int} The current page
   */
  getCurrentPage () {
    return parseInt(this.data.get('currentPage'));
  }

  /**
   * Sets up the bottom of the page for lazy loading: show the spinner,
   * hide the footer, remove the pagination links.
   */
  preparePage () {
    this.spinnerTarget.classList.add('loading--active');
    this.footer = document.querySelector('.footer');
    this.footer.style.display = 'none';
    this.paginatorTarget.parentNode.removeChild(this.paginatorTarget);
  }

  /**
   * Handler for the intersection observer that observes the loading spinner at the
   * bottom of the page. If it's visible, loads the next page.
   * @param {IntersectionObserverEntry[]} entries An array of intersection observer entries
   */
  handleIntersect (entries) {
    if (!entries.filter(entry => {
      return (entry.intersectionRatio > 0 || entry.isIntersecting);
    }).length) {
      return;
    }
    const nextPage = this.getCurrentPage() + 1;
    this.animateSpinner();
    fetch(`${this.data.get('baseUrl')}/page/${nextPage}.js`)
      .then(fetchStatus)
      .then(fetchText)
      .then(text => {
        this.stopSpinner();
        this.data.set('currentPage', nextPage);
        this.appendPage(text);
      })
      .catch(() => this.endInfiniteScroll());
  }

  /**
   * Creates an HTML fragment from a string of markup, appends it to the container.
   * @param {string} html The html to be inserted into the DOM
   */
  appendPage (html) {
    if (!html) {
      return;
    }
    const fragment = document.createRange().createContextualFragment(html);
    this.containerTarget.appendChild(fragment);
  }

  /**
   * If there are no more entries to be fetched, unobserves the spinner,
   * shows the footer again, and removes the spinner from the page.
   */
  endInfiniteScroll () {
    this.observer.unobserve(this.spinnerTarget);
    this.footer.style.display = 'block';
    this.spinnerTarget.parentNode.removeChild(this.spinnerTarget);
  }

  /**
   * Starts animating the spinner.
   */
  animateSpinner () {
    this.spinnerTarget.classList.add('loading--visible');
  }

  /**
   * Stops animating the spinner.
   */
  stopSpinner () {
    this.spinnerTarget.classList.remove('loading--visible');
  }
}
