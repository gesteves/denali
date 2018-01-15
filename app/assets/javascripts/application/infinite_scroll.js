//= require intersection-observer/intersection-observer
//= require masonry-layout/dist/masonry.pkgd.min.js
'use strict';

class InfiniteScroll {
  constructor (opts = {}) {
    const options = Object.assign({
      containerSelector: '.entry-list',
      itemSelector: '.entry-list__item',
      paginationSelector: '.pagination',
      sentinelSelector: '.loading',
      footerSelector: '.footer',
      activeClass: 'loading--active'
    }, opts);
    let pagination = document.querySelector(options.paginationSelector);
    let container = document.querySelector(options.containerSelector);
    let sentinel = document.querySelector(options.sentinelSelector);

    if (!container || !sentinel || !pagination) {
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

    this.masonry = new Masonry(this.container, {
      initLayout: false,
      itemSelector: options.itemSelector,
      percentPosition: true,
      stagger: 50,
      hiddenStyle: {
        opacity: 0
      },
      visibleStyle: {
        opacity: 1
      }
    });
    this.masonry.once('layoutComplete', () => {
      IntersectionObserver.prototype.POLL_INTERVAL = 50;
      this.loadingObserver = new IntersectionObserver(e => this.loadEntries(e), { rootMargin: '25%' });
      this.loadingObserver.observe(this.sentinel);
      this.paginationObserver = new IntersectionObserver(e => this.updatePage(e), { threshold: 1.0 });
      this.observePageUrls();
    });
    this.masonry.layout();
  }

  loadEntries (entries) {
    let entry,
        nextPage;
    let intersecting = entries.filter(entry => {
      return (entry.intersectionRatio > 0 || entry.isIntersecting);
    });
    if (intersecting.length > 0) {
      entry = intersecting[0];
      nextPage = this.currentPage + 1;
      if ('requestAnimationFrame' in window) {
        requestAnimationFrame(() => this.getPage(nextPage));
      } else {
        this.getPage(nextPage);
      }
    }
  }

  getPage (page) {
    let fragment;
    let children;
    let request = new XMLHttpRequest();
    request.open('GET', `${this.baseUrl}/page/${page}.js`, true);
    request.onload = () => {
      if (request.status >= 200 && request.status < 400) {
        fragment = document.createRange().createContextualFragment(request.responseText);
        children = Array.from(fragment.children);
        this.container.appendChild(fragment);
        this.masonry.appended(children);
        this.currentPage = page;
        this.observePageUrls();
      } else {
        this.loadingObserver.unobserve(this.sentinel);
        this.footer.style.display = 'block';
        this.sentinel.parentNode.removeChild(this.sentinel);
      }
    };
    request.send();
  }

  observePageUrls () {
    let elements = this.container.querySelectorAll('[data-page-url]');
    for (let i = 0; i < elements.length; i++) {
      let element = elements[i];
      this.paginationObserver.observe(element);
    }
  }

  updatePage (entries) {
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
        if (typeof ga !== 'undefined') {
          ga('set', 'page', window.location.pathname);
          ga('send', 'pageview');
        }
        if (typeof gtag !== 'undefined' && typeof gaTrackingId !== 'undefined') {
          gtag('config', gaTrackingId, { 'page_path': window.location.pathname });
        }
      }
    }
  }
}

if (document.readyState !== 'loading') {
  new InfiniteScroll();
} else {
  document.addEventListener('DOMContentLoaded', () => new InfiniteScroll());
}
