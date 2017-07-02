//= require intersection-observer/intersection-observer
'use strict';

class InfiniteScroll {
  constructor (container, sentinel, threshold = 0) {
    this.container = document.querySelector(container);
    this.baseUrl = this.container.getAttribute('data-base-url');
    this.nextPage = this.container.getAttribute('data-next-page');
    this.observer = new IntersectionObserver(entries => this.handleIntersection(entries), { rootMargin: `${threshold}px` });
    this.sentinel = document.querySelector(sentinel);
    this.sentinel.style.visibility = 'hidden';
    this.observer.observe(this.sentinel);
    this.loading = false;
  }

  handleIntersection (entries) {
    entries.forEach(entry => {
      if (entry.intersectionRatio > 0 || entry.isIntersecting) {
        this.getNextPage();
      }
    });
  }

  getNextPage () {
    let request = new XMLHttpRequest();
    request.open('GET', `${this.baseUrl}/page/${this.nextPage}.js`, true);
    request.onload = () => {
      if (request.status >= 200 && request.status < 400) {
        this.container.insertAdjacentHTML('beforeend', request.responseText);
        window.history.pushState(null, null, `${this.baseUrl}/page/${this.nextPage}`);
        this.nextPage = this.nextPage + 1;
      } else {
        this.observer.unobserve(this.sentinel);
      }
    };
    request.send();
  }
}

if (document.readyState !== 'loading') {
  new InfiniteScroll('.entry-list', '.pagination', 100);
} else {
  document.addEventListener('DOMContentLoaded', () => new InfiniteScroll('.entry-list', '.pagination', 100));
}
