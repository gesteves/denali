var Denali = Denali || {};

Denali.Flash = (function ($) {
  'use strict';

  var opts = {
    flash_selector  : '.flash',
    close_selector  : '.js-flash-close'
  };

  var flash;

  var init = function () {
    flash = $(opts.flash_selector);
    flash.on('click', opts.close_selector, closeFlash);
  };

  var closeFlash = function () {
    flash.fadeOut();
    return false;
  };

  return {
    init: init
  };
})(jQuery);

Denali.Flash.init();
