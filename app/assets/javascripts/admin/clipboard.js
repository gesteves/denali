var Denali = Denali || {};

Denali.Clipboard = (function ($) {
  'use strict';

  var opts = {
    selector  : '.js-clipboard'
  };

  var clipboard;
  var init = function () {
    $(opts.selector).on('click', function (e) {
      e.preventDefault();
    });
    clipboard = new Clipboard(opts.selector);
    clipboard.on('success', copySuccess);
  };

  var copySuccess = function (e) {
    e.clearSelection();
    $(e.trigger).html('Copied to clipboard!');
  };

  return {
    init: init
  };
})(jQuery);
