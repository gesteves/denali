//= require masonry-layout/dist/masonry.pkgd.min.js
'use strict';

class Grid {
  constructor (opts = {}) {
    const options = Object.assign({
      containerSelector: '.entry-list',
      itemSelector: '.entry-list__item'
    }, opts);
    let container = document.querySelector(options.containerSelector);

    if (!container) {
      return;
    }

    this.masonry = new Masonry(container, {
      itemSelector: options.itemSelector,
      horizontalOrder: true,
      gutter: 2,
      percentPosition: true,
      transitionDuration: 0
    });
  }
}

if (document.readyState !== 'loading') {
  new Grid();
} else {
  document.addEventListener('DOMContentLoaded', () => new Grid());
}
