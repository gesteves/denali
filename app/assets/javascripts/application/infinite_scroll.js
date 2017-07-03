//= require intersection-observer/intersection-observer
'use strict';

class InfiniteScroll {
  constructor () {
    this.pagination = document.querySelector('.pagination');
    if (!this.pagination) {
      return;
    }
    this.sentinel = this.setUpSentinel(this.pagination);
    this.container = document.querySelector('.entry-list');
    this.footer = document.querySelector('.footer');
    this.footer.style.opacity = 0;
    this.baseUrl = this.container.getAttribute('data-base-url');
    this.currentPage = parseInt(this.container.getAttribute('data-current-page'));
    this.loadObserver = new IntersectionObserver(entries => this.checkForNextPage(entries), { rootMargin: '100%' });
    this.loadObserver.observe(this.sentinel);
    this.pageObserver = new IntersectionObserver(entries => this.checkPagination(entries), { threshold: 1.0 });
    this.updatePageSentinels();
    this.loading = false;
  }

  setUpSentinel (element) {
    let parent = element.parentNode;
    let sentinel = document.createElement('div');
    parent.replaceChild(sentinel, element);
    return sentinel;
  }

  checkForNextPage (entries) {
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
        this.currentPage = nextPage;
        this.updatePageSentinels();
      } else {
        this.loadObserver.unobserve(this.sentinel);
        this.footer.style.opacity = 1;
      }
      this.loading = false;
    };
    this.loading = true;
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
  new InfiniteScroll();
} else {
  document.addEventListener('DOMContentLoaded', () => new InfiniteScroll());
}
