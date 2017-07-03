//= require intersection-observer/intersection-observer
'use strict';

class InfiniteScroll {
  constructor (container, pagination, footer) {
    this.pagination = document.querySelector(pagination);
    this.container = document.querySelector(container);
    if (!this.pagination || !this.container) {
      return;
    }
    this.sentinel = this.setUpSentinel(this.pagination);
    this.footer = document.querySelector(footer);
    this.footer.style.opacity = 0;
    this.baseUrl = this.container.getAttribute('data-base-url');
    this.currentPage = parseInt(this.container.getAttribute('data-current-page'));
    this.loadObserver = new IntersectionObserver(entries => this.checkForNextPage(entries), { rootMargin: '100%' });
    this.loadObserver.observe(this.sentinel);
    this.pageObserver = new IntersectionObserver(entries => this.checkPagination(entries), { threshold: 1.0 });
    this.updatePageSentinels();
  }

  setUpSentinel (element) {
    let parent = element.parentNode;
    let sentinel = document.createElement('div');
    parent.replaceChild(sentinel, element);
    return sentinel;
  }

  checkForNextPage (entries) {
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
        this.updatePageSentinels();
      } else {
        this.loadObserver.unobserve(this.sentinel);
        this.footer.style.opacity = 1;
      }
    };
    request.send();
  }

  updatePageSentinels () {
    let elements = this.container.querySelectorAll('[data-page-url]');
    elements.forEach(element => this.pageObserver.observe(element));
  }

  checkPagination (entries) {
    entries.forEach(entry => {
      if ((entry.intersectionRatio > 0 || entry.isIntersecting)) {
        window.history.replaceState(null, null, entry.target.getAttribute('data-page-url'));
      }
    });
  }
}

if (document.readyState !== 'loading') {
  new InfiniteScroll('.entry-list', '.pagination', '.footer');
} else {
  document.addEventListener('DOMContentLoaded', () => new InfiniteScroll('.entry-list', '.pagination', '.footer'));
}
