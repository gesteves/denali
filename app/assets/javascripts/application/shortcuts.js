var Denali = Denali || {};

Denali.Shortcuts = (function () {
  'use strict';
  var opts = {
    older_page : '.pagination a[rel=next]',
    newer_page : '.pagination a[rel=prev]',
    photos     : '.entry__image',
    zoom_class : 'entry__image--fit'
  };

  var older_page,
      newer_page,
      photos;

  var init = function () {
    document.addEventListener('keydown', doKeyPress);
    photos = document.querySelectorAll(opts.photos);
    older_page = document.querySelector(opts.older_page);
    newer_page = document.querySelector(opts.newer_page);
  };

  var doKeyPress = function (e) {
    var key = e.key || e.keyCode || e.which;
    var keys = {
      left  : 37,
      right : 39,
      up    : 38,
      down  : 40,
      j     : 74,
      k     : 75,
      z     : 90
    };

    if (!document.activeElement.tagName.match(/input|textarea/i) && !e.ctrlKey && !e.altKey && !e.metaKey) {
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
    }
  };

  var newerPage = function () {
    if (newer_page) {
      Turbolinks.visit(newer_page.getAttribute('href'));
    }
  };

  var olderPage = function () {
    if (older_page) {
      Turbolinks.visit(older_page.getAttribute('href'));
    }
  };

  var toggleZoom = function () {
    var photo;
    for (var i = 0; i < photos.length; i++) {
      photo = photos[i];
      photo.classList.toggle(opts.zoom_class);
    }
  };

  return {
    init : init
  };
})();

document.addEventListener('page:change', function() {
  'use strict';
  Denali.Shortcuts.init();
});
