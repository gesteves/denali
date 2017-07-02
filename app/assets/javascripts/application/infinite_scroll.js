//= require intersection-observer/intersection-observer
'use strict';

class InfiniteScroll {
  constructor (container, sentinel, threshold = 0) {
    this.container = document.querySelector(container);
    this.baseUrl = this.container.getAttribute('data-base-url');
    this.nextPage = parseInt(this.container.getAttribute('data-next-page'));
    this.sentinel = document.querySelector(sentinel);
    this.sentinel.classList.add('sentinel');
    this.observer = new IntersectionObserver(entries => this.handleIntersection(entries), { rootMargin: `${threshold}px` });
    this.observer.observe(this.sentinel);
    this.loading = false;
  }

  handleIntersection (entries) {
    entries.forEach(entry => {
      if ((entry.intersectionRatio > 0 || entry.isIntersecting) && !this.loading ){
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
        window.history.replaceState(null, null, `${this.baseUrl}/page/${this.nextPage}`);
        this.nextPage = this.nextPage + 1;
      } else {
        this.observer.unobserve(this.sentinel);
      }
      this.loading = false;
    };
    this.loading = true;
    request.send();
  }
}

if (document.readyState !== 'loading') {
  new InfiniteScroll('.entry-list', '.pagination', 150);
} else {
  document.addEventListener('DOMContentLoaded', () => new InfiniteScroll('.entry-list', '.pagination', 150));
}
