var Denali = Denali || {};

Denali.Shortcuts = (function ($) {
  'use strict';
  var opts = {
    older_page : $('.pagination a[rel=next]'),
    newer_page : $('.pagination a[rel=prev]'),
    photos     : $('.entry__photo-link'),
    zoom_class : 'entry__photo-link--fit'
  };

  var $document = $(document);

  var init = function () {
    $document.on('keydown', doKeyPress);
  };

  var doKeyPress = function (e) {
    var key = e.keyCode || e.which;
    var keys = {
      left  : 37,
      right : 39,
      up    : 38,
      down  : 40,
      j     : 74,
      k     : 75,
      z     : 90
    };
    switch (key) {
      case keys.left:
      case keys.j:
        newerPage();
        break;
      case keys.right:
      case keys.k:
        olderPage();
        break;
      case keys.z:
        toggleZoom();
        break;
    }
  };

  var newerPage = function () {
    if (opts.newer_page.length && !$('input, textarea').is(':focus')) {
      window.location.href = opts.newer_page.attr('href');
    }
  };

  var olderPage = function () {
    if (opts.older_page.length && !$('input, textarea').is(':focus')) {
      window.location.href = opts.older_page.attr('href');
    }
  };

  var toggleZoom = function () {
    opts.photos.toggleClass(opts.zoom_class);
    return false;
  };

  return {
    init : init
  };
})(jQuery);

Denali.Shortcuts.init();
