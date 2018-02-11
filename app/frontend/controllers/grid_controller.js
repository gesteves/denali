import 'intersection-observer';
import Masonry                    from 'masonry-layout';
import { fetchStatus, fetchText } from '../lib/utils';
import { Controller }             from 'stimulus';

/**
 * Controls the Masonry grid and infinite loading of entries on the
 * entries#index and entries#tagged views.
 * TODO: It'd be nice to split the Masonry and infinite loading functionality
 * into separate controllers, and make the infinite loading generic.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['container', 'paginator', 'spinner'];

  connect () {
    // Set up basic masonry layout
    this.masonry = new Masonry(this.containerTarget, {
      initLayout: false,
      itemSelector: '.entry-list__item',
      percentPosition: true,
      hiddenStyle: {
        opacity: 0
      },
      visibleStyle: {
        opacity: 1
      }
    });

    // If there's no loading spinner, there's nothing to observe.
    // If there's no paginator, it means there are no more pages to load.
    // In either of these cases, return early but init the masonry layout first.
    if (!this.hasSpinnerTarget || !this.hasPaginatorTarget) {
      this.masonry.layout();
      return;
    }

    // Set up the bottom of the page for lazy loading: show the spinner,
    // hide the footer, remove the pagination links.
    this.spinnerTarget.classList.add('loading--active');
    this.footer = document.querySelector('.footer');
    this.footer.style.display = 'none';
    this.paginatorTarget.parentNode.removeChild(this.paginatorTarget);

    // Set up an event handler so that once the masonry layout is in place,
    // it sets up the intersection observer:
    this.masonry.once('layoutComplete', () => this.initObserver());

    // Finally, init the masonry layout.
    this.masonry.layout();
  }

  /**
   * Sets up `observer` intersection observer, which observes the spinner at the
   * bottom of the page, and loads more pages when it's in view
   */
  initObserver () {
    this.observer = new IntersectionObserver(e => this.handleSpinnerIntersect(e), { rootMargin: '25%' });
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
   * Handler for the intersection observer that observes the loading spinner at the
   * bottom of the page. If it's visible, loads the next page.
   * @param {IntersectionObserverEntry[]} entries An array of intersection observer entries
   */
  handleSpinnerIntersect (entries) {
    if (!entries.filter(entry => {
      return (entry.intersectionRatio > 0 || entry.isIntersecting);
    }).length) {
      return;
    }
    const nextPage = this.getCurrentPage() + 1;
    fetch(`${this.data.get('baseUrl')}/page/${nextPage}.js`)
    .then(fetchStatus)
    .then(fetchText)
    .then(text => this.appendPage(text, nextPage))
    .catch(() => this.endInfiniteScroll());
  }

  /**
   * Creates an HTML fragment from a string of markup, appends it to the container,
   * and adjusts the masonry
   * @param {string} html The html to be inserted into the DOM
   */
  appendPage (html, page) {
    if (!html) {
      return;
    }
    const fragment = document.createRange().createContextualFragment(html);
    const children = Array.from(fragment.children);
    this.data.set('currentPage', page);
    this.containerTarget.appendChild(fragment);
    this.masonry.appended(children);
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
}
