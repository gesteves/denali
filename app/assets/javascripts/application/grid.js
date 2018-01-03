//= require salvattore/dist/salvattore.min.js
'use strict';

class Grid {
  constructor (opts = {}) {
    const options = Object.assign({
      gridSelector: '.entry-list'
    }, opts);
    this.grid = document.querySelector(options.gridSelector);
    salvattore.registerGrid(this.grid);
  }
}

if (document.readyState !== 'loading') {
  new Grid();
} else {
  document.addEventListener('DOMContentLoaded', () => new Grid());
}
