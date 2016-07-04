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
  var requested_animation_frame = false;

  var init = function () {
    zoomable_images = [];
    var images = document.querySelectorAll(opts.images);
    var image,
        original_width,
        original_height,
        image_ratio,
        max_width,
        min_height,
        height;
    for (var i = 0; i < images.length; i++) {
      image = images[i];
      original_height = parseInt(image.getAttribute('data-height-original'));
      original_width = parseInt(image.getAttribute('data-width-original'));
      image_ratio = original_height/original_width;
      max_width = Math.min(original_width, document.documentElement.clientWidth, opts.max_width);
      height = max_width * image_ratio;
      min_height = Math.min(document.documentElement.clientHeight, height);
      image.style.minHeight = min_height + 'px';
      if (height > document.documentElement.clientHeight) {
        image.classList.add(opts.zoomable_class);
        image.addEventListener('click', toggleZoom);
        zoomable_images.push(image);
      } else {
        image.classList.remove(opts.zoomable_class);
        image.removeEventListener('click', toggleZoom);
      }
    }
    requested_animation_frame = false;
  };

  var toggleZoom = function (e) {
    e.preventDefault();
    for (var i = 0; i < zoomable_images.length; i++) {
      zoomable_images[i].classList.toggle(opts.zoom_class);
    }
  };

  var handleResize = function () {
    if (requested_animation_frame) {
      return;
    }
    requested_animation_frame = true;
    requestAnimationFrame(init);
  };

  return {
    init : init,
    handleResize: handleResize
  };
})();
