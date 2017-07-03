//= require intersection-observer/intersection-observer
'use strict';

class InfiniteScroll {
  constructor (containerSelector, paginationSelector, footerSelector) {
    let pagination = document.querySelector(paginationSelector);
    this.container = document.querySelector(containerSelector);
    if (!pagination || !this.container) {
      return;
    }
    this.pagination = this.setUpPagination(pagination);
    this.button = this.setUpButton();
    this.footer = document.querySelector(footerSelector);
    this.baseUrl = this.container.getAttribute('data-base-url');
    this.currentPage = parseInt(this.container.getAttribute('data-current-page'));
    this.loadingObserver = new IntersectionObserver(entries => this.checkForNextPage(entries), { rootMargin: '50%' });
    this.loadingObserver.observe(this.pagination);
    this.pageNumberObserver = new IntersectionObserver(entries => this.setPageNumber(entries), { threshold: 1.0 });
    this.updatePageNumberObserver();
    this.showButton();
    this.hide(this.footer);
  }

  setUpPagination (element) {
    element.innerHTML = '<a href="#" class="hidden">More »</a>';
    return element;
  }

  setUpButton () {
    let button = this.pagination.querySelector('a');
    button.addEventListener('click', e => {
      e.preventDefault();
      this.getNextPage();
    });
    return button;
  }

  showButton () {
    this.buttonTimeout = setTimeout(() => {
      this.show(this.button);
    }, 1000);
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
    clearTimeout(this.buttonTimeout);
    this.hide(this.button);
    request.open('GET', `${this.baseUrl}/page/${nextPage}.js`, true);
    request.onload = () => {
      if (request.status >= 200 && request.status < 400) {
        this.container.insertAdjacentHTML('beforeend', request.responseText);
        this.currentPage = nextPage;
        this.updatePageNumberObserver();
        this.showButton();
      } else {
        this.loadingObserver.unobserve(this.pagination);
        this.remove(this.pagination);
        this.show(this.footer);
      }
    };
    request.send();
  }

  updatePageNumberObserver () {
    let elements = this.container.querySelectorAll('[data-page-url]');
    elements.forEach(element => this.pageNumberObserver.observe(element));
  }

  setPageNumber (entries) {
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

  hide (element) {
    element.classList.add('hidden');
  }

  show (element) {
    element.classList.remove('hidden');
  }

  remove (element) {
    element.parentNode.removeChild(element);
  }
}

if (document.readyState !== 'loading') {
  new InfiniteScroll('.entry-list', '.pagination', '.footer');
} else {
  document.addEventListener('DOMContentLoaded', () => new InfiniteScroll('.entry-list', '.pagination', '.footer'));
}
