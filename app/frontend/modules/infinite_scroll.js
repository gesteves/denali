import 'intersection-observer';
import Masonry from 'masonry-layout';

class InfiniteScroll {
  constructor (options) {

    // These elements are required for the infinite scroll to function:
    // - `container` is the list of entries on the page.
    // - `pagination` are the "next" and "previous" links on the page, only present
    //    if there's more than one page of entries and used as a fallback if JS fails.
    // - `sentinel` is the element at the bottom of the page that is used both as a
    //    loading spinner as new pages are loading, and as a target for the intersection
    //    observer to check if we've reached the bottom of the page, and thus should
    //    load the next page of entries.
    this.container = document.querySelector(options.containerSelector);
    this.pagination = document.querySelector(options.paginationSelector);
    this.sentinel = document.querySelector(options.sentinelSelector);

    // No point in doing anything if there's no container
    if (!this.container) {
      return;
    }

    // Set up basic masonry layout
    this.masonry = new Masonry(this.container, {
      initLayout: false,
      itemSelector: options.itemSelector,
      percentPosition: true,
      hiddenStyle: {
        opacity: 0
      },
      visibleStyle: {
        opacity: 1
      }
    });

    // If there's no sentinel, there's nothing to observe.
    // If there's no pagination, it means there are no more pages to load.
    // In either of these cases, return early but init the masonry layout first.
    if (!this.sentinel || !this.pagination) {
      this.masonry.layout();
      return;
    }

    // Set up the bottom of the page for lazy loading: show the sentinel,
    // hide the footer, remove the pagination links.
    this.sentinel.classList.add(options.activeClass);
    this.footer = document.querySelector(options.footerSelector);
    this.footer.style.display = 'none';
    this.loadingClass = options.loadingClass;
    this.pagination.parentNode.removeChild(this.pagination);

    // Store the base URL of the page and the current page number so we can
    // update the URL in the address bar later.
    this.baseUrl = this.container.getAttribute('data-base-url');
    this.currentPage = parseInt(this.container.getAttribute('data-current-page'));

    // Set up an event handler so that once the masonry layout is complete,
    // it sets up separate intersection observers:
    // one observes the sentinel at the bottom of the page, and loads more pages;
    // the other observes the first item of each page,
    // which updates the URL in the address bar as we scroll.
    this.masonry.once('layoutComplete', () => {
      IntersectionObserver.prototype.POLL_INTERVAL = 50;
      this.loadingObserver = new IntersectionObserver(e => this.handlePageBottom(e), { rootMargin: '25%' });
      this.loadingObserver.observe(this.sentinel);
      this.paginationObserver = new IntersectionObserver(e => this.updatePagePath(e), { threshold: 1.0 });
      this.observePageUrls();
    });

    // Finally, init the masonry layout.
    this.masonry.layout();
  }

  // Handler for the intersection observer that observes the sentinel at the
  // bottom of the page. If it's visible, loads the next page.
  handlePageBottom (entries) {
    let intersecting = entries.filter(entry => {
      return (entry.intersectionRatio > 0 || entry.isIntersecting);
    });
    if (intersecting.length > 0) {
      let nextPage = this.currentPage + 1;
      this.getPage(nextPage);
    }
  }

  // Fetches the next page of results, and either inserts it
  // into the DOM, or ends the infinite scroll process if there are no
  // more results (if so, server returns 404).
  getPage (page) {
    fetch(`${this.baseUrl}/page/${page}.js`).then(response => {
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
    let fragment = document.createRange().createContextualFragment(html);
    let children = Array.from(fragment.children);
    this.currentPage = page;
    this.container.appendChild(fragment);
    this.masonry.appended(children);
    this.observePageUrls();
  }

  // If there are no more entries to be fetched, unobserves the sentinel,
  // shows the footer again, and removes the sentinel from the page.
  endInfiniteScroll () {
    this.loadingObserver.unobserve(this.sentinel);
    this.footer.style.display = 'block';
    this.sentinel.parentNode.removeChild(this.sentinel);
  }

  // The first element of each page fetched contains a `data-page-url` data attribute
  // with the full URL of its parent page. This function makes the intersection observer
  // observe these new elements as they're added so we can update the URL in the
  // browser as we scroll.
  observePageUrls () {
    let elements = this.container.querySelectorAll('[data-page-url]');
    for (let i = 0; i < elements.length; i++) {
      let element = elements[i];
      this.paginationObserver.observe(element);
    }
  }

  // Handler for the pagination intersection observer, which observes the first
  // element of each new page and checks their `data-page-url` data attribute.
  // As each element is in view, this function uses that data attribute to
  // update the URL in the browser address bar using the History API, and
  // tracks the page view in Analytics if the page changes.
  updatePagePath (entries) {
    let entry,
        previous_path;
    let intersecting = entries.filter(entry => {
      return (entry.intersectionRatio > 0 || entry.isIntersecting);
    });
    if (intersecting.length > 0) {
      entry = intersecting[0];
      previous_path = window.location.pathname;
      window.history.replaceState(null, null, entry.target.getAttribute('data-page-url'));
      if (previous_path !== window.location.pathname) {
        if ('requestIdleCallback' in window) {
          requestIdleCallback(this.trackPageView);
        } else {
          this.trackPageView();
        }
      }
    }
  }

  // Makes a Google Analytics page view tracking call.
  trackPageView () {
    if (typeof ga !== 'undefined') {
      ga('set', 'page', window.location.pathname);
      ga('send', 'pageview');
    }
    if (typeof gtag !== 'undefined' && typeof gaTrackingId !== 'undefined') {
      gtag('config', gaTrackingId, { 'page_path': window.location.pathname });
    }
  }
}

export default InfiniteScroll;
