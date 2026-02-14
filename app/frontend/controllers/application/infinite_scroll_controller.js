import { Controller } from '@hotwired/stimulus';

/**
 * Controls the infinite loading of entries on the
 * entries#index, entries#tagged, and entries#search views.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['container', 'paginator', 'spinner'];
  static values = {
    currentPage: Number,
    baseUrl: String
  }

  connect () {
    const botUserAgents = /(googlebot|google-structured-data-testing-tool|bingbot|mediapartners-google)/i;

    // If there's no loading spinner, there's nothing to observe.
    // If there's no paginator, it means there are no more pages to load.
    // If it's a bot, we don't want infinite scrolling.
    // In any of these cases, or if intersection observer isn't supported, return early.
    if (navigator.userAgent.match(botUserAgents) || !this.hasSpinnerTarget || !this.hasPaginatorTarget || !('IntersectionObserver' in window)) {
      return;
    }

    this.loading = false;
    this.preparePage();

    // Set up an intersection observer to observe the loading spinner at the bottom.
    // When it's in view, fetch the next page.
    this.observer = new IntersectionObserver(e => this.handleIntersect(e), { rootMargin: '50%' });
    this.observer.observe(this.spinnerTarget);
  }

  disconnect () {
    this.observer?.disconnect();
    if (this.footer) {
      this.footer.style.display = 'block';
      this.footer.setAttribute('aria-hidden', 'false');
    }
  }

  /**
   * Sets up the bottom of the page for lazy loading: show the spinner,
   * hide the footer and the pagination links.
   */
  preparePage () {
    this.spinnerTarget.classList.add('loading--active');
    this.footer = document.querySelector('#footer');
    if (this.footer) {
      this.footer.style.display = 'none';
      this.footer.setAttribute('aria-hidden', 'true');
    }
    this.paginatorTarget.style.display = 'none';
    this.paginatorTarget.setAttribute('aria-hidden', 'true');
  }

  /**
   * Handler for the intersection observer that observes the loading spinner at the
   * bottom of the page. If it's visible, loads the next page.
   * @param {IntersectionObserverEntry[]} entries An array of intersection observer entries
   */
  async handleIntersect (entries) {
    if (!entries.some(entry => entry.intersectionRatio > 0 || entry.isIntersecting)) {
      return;
    }
    if (this.loading) return;
    this.loading = true;
    const nextPage = this.currentPageValue + 1;
    this.animateSpinner();
    // Handle query-parameter-based URLs (e.g., /search?q=term) vs path-based URLs (e.g., /entries)
    let url;
    if (this.baseUrlValue.includes('?')) {
      // For query-parameter URLs, insert .js before the query string
      const [basePath, queryString] = this.baseUrlValue.split('?');
      url = `${basePath}.js?${queryString}&page=${nextPage}`;
    } else {
      // For path-based URLs, use the existing format
      url = `${this.baseUrlValue}/page/${nextPage}.js`;
    }
    try {
      const response = await fetch(url);
      if (!response.ok) throw new Error(response.status);
      const text = await response.text();
      this.stopSpinner();
      this.currentPageValue = nextPage;
      this.appendPage(text);
    } catch {
      this.endInfiniteScroll();
    } finally {
      this.loading = false;
    }
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
    if (this.footer) {
      this.footer.style.display = 'block';
      this.footer.setAttribute('aria-hidden', 'false');
    }
    this.spinnerTarget.remove();
    this.containerTarget.setAttribute('aria-busy', 'false');
  }

  /**
   * Starts animating the spinner.
   */
  animateSpinner () {
    this.spinnerTarget.classList.add('loading--visible');
    this.spinnerTarget.setAttribute('aria-hidden', 'false');
    this.containerTarget.setAttribute('aria-busy', 'true');
  }

  /**
   * Stops animating the spinner.
   */
  stopSpinner () {
    this.spinnerTarget.classList.remove('loading--visible');
    this.spinnerTarget.setAttribute('aria-hidden', 'true');
    this.containerTarget.setAttribute('aria-busy', 'false');
  }
}
