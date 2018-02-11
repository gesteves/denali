import 'intersection-observer';
import Masonry                    from 'masonry-layout';
import { fetchStatus, fetchText } from '../lib/utils';
import { trackPageView }          from '../lib/analytics';
import { Controller }             from 'stimulus';

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
    // it sets up the intersection observers:
    this.masonry.once('layoutComplete', () => this.initObservers());

    // Finally, init the masonry layout.
    this.masonry.layout();
  }

  /**
   * Sets up two separate intersection observers:
   * `spinnerObserver` observes the spinner at the bottom of the page, and loads more pages;
   * `paginationObserver` observes the first item of each page, which updates the URL in the address bar
   */
  initObservers () {
    this.spinnerObserver = new IntersectionObserver(e => this.handleSpinnerIntersect(e), { rootMargin: '25%' });
    this.spinnerObserver.observe(this.spinnerTarget);
    this.paginationObserver = new IntersectionObserver(e => this.handlePaginationIntersect(e), { threshold: 1.0 });
    // Enable polling on the polyfill to work around some Safari weirdness
    this.spinnerObserver.POLL_INTERVAL = 50;
    this.paginationObserver.POLL_INTERVAL = 50;
    // Watch page numbers
    this.observePageUrls();
  }

  /**
   * Convenience function to check if an IO entry intersects the root
   * @param {Object} entry An intersection observer entry
   * @return {boolean} Whether or not it intersects
   */
  isIntersecting (entry) {
    return (entry.intersectionRatio > 0 || entry.isIntersecting);
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
   * @param {Object} entries A list of intersection observer entries
   */
  handleSpinnerIntersect (entries) {
    if (!entries.filter(this.isIntersecting).length) {
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
   * adjusts the masonry, and observes the new elements.
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
    this.observePageUrls();
  }

  /**
   * If there are no more entries to be fetched, unobserves the spinner,
   * shows the footer again, and removes the spinner from the page.
   */
  endInfiniteScroll () {
    this.spinnerObserver.unobserve(this.spinnerTarget);
    this.footer.style.display = 'block';
    this.spinnerTarget.parentNode.removeChild(this.spinnerTarget);
  }

  /**
    * Adds the first element of each page to the `paginationObserver`.
    * These are used to update the URL in the address bar.
    */
  observePageUrls () {
    const elements = this.containerTarget.querySelectorAll('[data-page-url]');
    elements.forEach(element => this.paginationObserver.observe(element));
  }

  /**
    * Handler for the `paginationObserver`, which observes the first
    * element of each new page and checks their `data-page-url` data attribute.
    * As each element is in view, this function uses that data attribute to
    * update the URL in the browser address bar using the History API, and
    * tracks the page view in Analytics if the page changes.
    * @param {Object} entries A list of intersection observer entries
    */
  handlePaginationIntersect (entries) {
    const intersecting = entries.filter(this.isIntersecting);
    if (!intersecting.length) {
      return;
    }
    const entry = intersecting[0];
    const previous_path = window.location.pathname;
    window.history.replaceState(null, null, entry.target.getAttribute('data-page-url'));
    if (previous_path !== window.location.pathname) {
      trackPageView();
    }
  }
}
