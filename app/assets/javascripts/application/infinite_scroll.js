//= require intersection-observer/intersection-observer
'use strict';

class InfiniteScroll {
  constructor (container, pagination = '.pagination', rootMargin = '100px') {
    this.sentinel = this.setUpSentinel(pagination);
    this.container = document.querySelector(container);
    this.baseUrl = this.container.getAttribute('data-base-url');
    this.currentPage = parseInt(this.container.getAttribute('data-current-page'));
    this.observer = new IntersectionObserver(entries => this.handleIntersection(entries), { rootMargin: rootMargin });
    this.observer.observe(this.sentinel);
    this.loading = false;
  }

  setUpSentinel (selector) {
    let element = document.querySelector(selector);
    let parent = element.parentNode;
    let sentinel = document.createElement('div');
    parent.replaceChild(sentinel, element);
    return sentinel;
  }

  handleIntersection (entries) {
    entries.forEach(entry => {
      if ((entry.intersectionRatio > 0 || entry.isIntersecting) && !this.loading) {
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
        window.history.replaceState(null, null, `${this.baseUrl}/page/${nextPage}`);
        this.currentPage = nextPage;
        if (typeof ga !== 'undefined') {
          ga('set', 'page', window.location.pathname);
          ga('send', 'pageview');
        }
      } else {
        this.observer.unobserve(this.sentinel);
        this.footer.style.opacity = 1;
      }
      this.loading = false;
    };
    this.loading = true;
    request.send();
  }
}

if (document.readyState !== 'loading') {
  new InfiniteScroll('.entry-list');
} else {
  document.addEventListener('DOMContentLoaded', () => new InfiniteScroll('.entry-list'));
}
