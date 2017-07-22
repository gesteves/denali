//= require intersection-observer/intersection-observer
'use strict';

class InfiniteScroll {
  constructor (opts = {}) {
    const options = Object.assign({
      containerSelector: '.entry-list',
      paginationSelector: '.pagination',
      sentinelSelector: '.loading',
      footerSelector: '.footer',
      activeClass: 'loading--active'
    }, opts);
    let pagination = document.querySelector(options.paginationSelector);
    let container = document.querySelector(options.containerSelector);
    let sentinel = document.querySelector(options.sentinelSelector);

    if (!container || !sentinel) {
      return;
    }

    this.container = container;
    this.sentinel = sentinel;
    this.sentinel.classList.add(options.activeClass);
    this.footer = document.querySelector(options.footerSelector);
    this.footer.style.display = 'none';
    this.loadingClass = options.loadingClass;
    pagination.parentNode.removeChild(pagination);

    this.baseUrl = this.container.getAttribute('data-base-url');
    this.currentPage = parseInt(this.container.getAttribute('data-current-page'));

    IntersectionObserver.prototype.POLL_INTERVAL = 50;
    this.loadingIO = new IntersectionObserver(e => this.loadEntries(e), { rootMargin: '50%' });
    this.loadingIO.observe(this.sentinel);
    this.paginationIO = new IntersectionObserver(e => this.updatePage(e), { threshold: 1.0 });
    this.observePageUrls();
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
        this.sentinel.parentNode.removeChild(this.sentinel);
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
  new InfiniteScroll();
} else {
  document.addEventListener('DOMContentLoaded', () => new InfiniteScroll());
}
