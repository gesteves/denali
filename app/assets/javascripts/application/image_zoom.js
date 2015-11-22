var Denali = Denali || {};

Denali.ImageZoom = (function () {
  'use strict';

  var opts = {
    images          : '.entry__image',
    zoomable_class  : 'entry__image--zoomable',
    zoom_class      : 'entry__image--fit',
    max_width       : 1440
  };

  var zoomable_images;
  var init = function () {
    zoomable_images = [];
    var images = document.querySelectorAll(opts.images);
    var image,
        original_width,
        original_height,
        image_ratio,
        max_width,
        height;
    for (var i = 0; i < images.length; i++) {
      image = images[i];
      original_height = parseInt(image.getAttribute('data-height-original'));
      original_width = parseInt(image.getAttribute('data-width-original'));
      image_ratio = original_height/original_width;
      max_width = Math.min(original_width, window.innerWidth, opts.max_width);
      height = max_width * image_ratio;
      if (height > window.innerHeight) {
        image.classList.add(opts.zoomable_class);
        image.style.minHeight = window.innerHeight + 'px';
        image.addEventListener('click', toggleZoom);
        zoomable_images.push(image);
      } else {
        image.classList.remove(opts.zoomable_class);
        image.style.minHeight = height + 'px';
        image.removeEventListener('click', toggleZoom);
      }
    }
  };

  var toggleZoom = function (e) {
    e.preventDefault();
    for (var i = 0; i < zoomable_images.length; i++) {
      zoomable_images[i].classList.toggle(opts.zoom_class);
    }
  };

  return {
    init : init
  };
})();
