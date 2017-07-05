//= require intersection-observer/intersection-observer
'use strict';

class InfiniteScroll {
  constructor (containerSelector, paginationSelector, footerSelector) {
    let pagination = document.querySelector(paginationSelector);
    let container = document.querySelector(containerSelector);
    if (!pagination || !container) {
      return;
    }
    this.container = container;
    this.sentinel = this.setUpSentinel(pagination);

    this.footer = document.querySelector(footerSelector);
    this.footer.style.display = 'none';

    this.baseUrl = this.container.getAttribute('data-base-url');
    this.currentPage = parseInt(this.container.getAttribute('data-current-page'));

    IntersectionObserver.prototype.POLL_INTERVAL = 100;
    this.loadingIO = new IntersectionObserver(e => this.loadEntries(e), { rootMargin: '50%' });
    this.loadingIO.observe(this.sentinel);
    this.paginationIO = new IntersectionObserver(e => this.updatePage(e), { threshold: 1.0 });
    this.observePageUrls();
  }

  setUpSentinel (element) {
    let parent = element.parentNode;
    let sentinel = document.createElement('div');
    parent.replaceChild(sentinel, element);
    return sentinel;
  }

  loadEntries (entries) {
    entries.forEach(entry => {
      if ((entry.intersectionRatio > 0 || entry.isIntersecting)) {
        this.getNextPage();
      }
    });
  }

  getNextPage () {
    let request = new XMLHttpRequest();
    let nextPage = this.currentPage + 1;
    request.open('GET', `${this.baseUrl}/page/${nextPage}.js`, true);
    request.onload = () => {
      if (request.status >= 200 && request.status < 400) {
        this.container.insertAdjacentHTML('beforeend', request.responseText);
        this.currentPage = nextPage;
        this.observePageUrls();
      } else {
        this.loadingIO.unobserve(this.sentinel);
        this.footer.style.display = 'block';
      }
    };
    request.send();
  }

  observePageUrls () {
    let elements = this.container.querySelectorAll('[data-page-url]');
    elements.forEach(element => this.paginationIO.observe(element));
  }

  updatePage (entries) {
    entries.forEach(entry => {
      if ((entry.intersectionRatio > 0 || entry.isIntersecting)) {
        window.history.replaceState(null, null, entry.target.getAttribute('data-page-url'));
        if (typeof ga !== 'undefined') {
          ga('set', 'page', window.location.pathname);
          ga('send', 'pageview');
        }
      }
    });
  }
}

if (document.readyState !== 'loading') {
  new InfiniteScroll('.entry-list', '.pagination', '.footer');
} else {
  document.addEventListener('DOMContentLoaded', () => new InfiniteScroll('.entry-list', '.pagination', '.footer'));
}
