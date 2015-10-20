var Denali = Denali || {};

Denali.Grid = (function () {
  'use strict';

  var opts = {
    grid_selector : '[data-columns]'
  };

  var init = function () {
    var grid = document.querySelector(opts.grid_selector);
    if (grid.getAttribute('data-columns') === '') {
      salvattore.registerGrid(grid);
    }
  };

  return {
    init: init
  };
})();
