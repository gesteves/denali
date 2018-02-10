import 'intersection-observer';
import Masonry from 'masonry-layout';
import { trackPageView } from '../lib/analytics';
import { Controller } from 'stimulus';

export default class extends Controller {
  static targets = ['container', 'paginator', 'sentinel'];

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

    // If there's no sentinel, there's nothing to observe.
    // If there's no paginator, it means there are no more pages to load.
    // In either of these cases, return early but init the masonry layout first.
    if (!this.hasSentinelTarget || !this.hasPaginatorTarget) {
      this.masonry.layout();
      return;
    }

    // Set up the bottom of the page for lazy loading: show the sentinel,
    // hide the footer, remove the pagination links.
    this.sentinelTarget.classList.add('loading--active');
    this.footer = document.querySelector('.footer');
    this.footer.style.display = 'none';
    this.paginatorTarget.parentNode.removeChild(this.paginatorTarget);

    // Set up an event handler so that once the masonry layout is in place,
    // it sets up the intersection observers:
    this.masonry.once('layoutComplete', () => this.initObservers());

    // Finally, init the masonry layout.
    this.masonry.layout();
  }

  // Sets up separate intersection observers:
  // 1) Observes the sentinel at the bottom of the page, and loads more pages;
  // 2) Observes the first item of each page, which updates the URL in the address bar
  initObservers () {
    IntersectionObserver.prototype.POLL_INTERVAL = 50;
    this.loadingObserver = new IntersectionObserver(e => this.handlePageBottom(e), { rootMargin: '25%' });
    this.loadingObserver.observe(this.sentinelTarget);
    this.paginationObserver = new IntersectionObserver(e => this.updatePagePath(e), { threshold: 1.0 });
    this.observePageUrls();
  }

  // Checks if an IO entry intersects the root
  isIntersecting (entry) {
    return (entry.intersectionRatio > 0 || entry.isIntersecting);
  }

  getCurrentPage () {
    return parseInt(this.data.get('currentPage'));
  }

  // Handler for the intersection observer that observes the sentinel at the
  // bottom of the page. If it's visible, loads the next page.
  handlePageBottom (entries) {
    if (entries.filter(this.isIntersecting).length) {
      this.getPage(this.getCurrentPage() + 1);
    }
  }

  // Fetches the next page of results, and either inserts it
  // into the DOM, or ends the infinite scroll process if there are no
  // more results (if so, server returns 404).
  getPage (page) {
    fetch(`${this.data.get('baseUrl')}/page/${page}.js`).then(response => {
      if (response.ok) {
        return response.text();
      } else {
        this.endInfiniteScroll();
      }
    }).then(text => { this.appendPage(page, text); });
  }

  // Creates an HTML fragment from a string of markup, appends it to the container,
  // adjusts the masonry, and observes the new elements.
  appendPage (page, html) {
    const fragment = document.createRange().createContextualFragment(html);
    const children = Array.from(fragment.children);
    this.data.set('currentPage', page);
    this.containerTarget.appendChild(fragment);
    this.masonry.appended(children);
    this.observePageUrls();
  }

  // If there are no more entries to be fetched, unobserves the sentinel,
  // shows the footer again, and removes the sentinel from the page.
  endInfiniteScroll () {
    this.loadingObserver.unobserve(this.sentinelTarget);
    this.footer.style.display = 'block';
    this.sentinelTarget.parentNode.removeChild(this.sentinelTarget);
  }

  // The first element of each page fetched contains a `data-page-url` data attribute
  // with the full URL of its parent page. This function makes the intersection observer
  // observe these new elements as they're added so we can update the URL in the
  // browser as we scroll.
  observePageUrls () {
    const elements = this.containerTarget.querySelectorAll('[data-page-url]');
    elements.forEach(element => this.paginationObserver.observe(element));
  }

  // Handler for the pagination intersection observer, which observes the first
  // element of each new page and checks their `data-page-url` data attribute.
  // As each element is in view, this function uses that data attribute to
  // update the URL in the browser address bar using the History API, and
  // tracks the page view in Analytics if the page changes.
  updatePagePath (entries) {
    const intersecting = entries.filter(this.isIntersecting);
    if (intersecting.length) {
      const entry = intersecting[0];
      const previous_path = window.location.pathname;
      window.history.replaceState(null, null, entry.target.getAttribute('data-page-url'));
      if (previous_path !== window.location.pathname) {
        trackPageView();
      }
    }
  }
}
