var Denali = Denali || {};

Denali.ImageZoom = (function () {
  'use strict';

  var opts = {
    images          : '.entry__image',
    zoomable_class  : 'entry__image--zoomable',
    zoom_class      : 'entry__image--fit'
  };

  var init = function () {
    var images = document.querySelectorAll(opts.images);
    var image,
        height;
    for (var i = 0; i < images.length; i++) {
      image = images[i];
      height = parseInt(image.getAttribute('data-height-original'));
      if (height > window.innerHeight) {
        image.classList.add(opts.zoomable_class);
        image.addEventListener('click', toggleZoom);
      }
    }
  };

  var toggleZoom = function (e) {
    e.preventDefault();
    e.currentTarget.classList.toggle(opts.zoom_class);
  };

  return {
    init : init
  };
})();

document.addEventListener('DOMContentLoaded', function() {
  'use strict';
  Denali.ImageZoom.init();
});
