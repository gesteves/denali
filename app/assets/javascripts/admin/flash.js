var Denali = Denali || {};

Denali.Flash = (function ($) {
  'use strict';

  var opts = {
    flash_selector  : '.flash',
    close_selector  : '.js-flash-close',
    timeout_length  : 5000
  };

  var flash,
      timeout_id;

  var init = function () {
    flash = $(opts.flash_selector);
    flash.on('click', opts.close_selector, closeFlash);
    timeout_id = setTimeout(function () {
      flash.fadeOut();
    }, opts.timeout_length);
  };

  var closeFlash = function () {
    flash.fadeOut();
    clearTimeout(timeout_id);
    return false;
  };

  return {
    init: init
  };
})(jQuery);
