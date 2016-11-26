var Denali = Denali || {};

Denali.ImageZoom = (function () {
  'use strict';

  var opts = {
    images          : '.entry__photo',
    zoomable_class  : 'entry__photo--zoomable',
    zoom_class      : 'entry__photo-container--zoom',
    max_width       : 1680
  };

  var zoomable;
  var requested_animation_frame = false;

  var init = function () {
    zoomable = [];
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
      max_width = Math.min(original_width, document.documentElement.clientWidth, opts.max_width);
      height = max_width * image_ratio;
      if (height > document.documentElement.clientHeight) {
        image.classList.add(opts.zoomable_class);
        image.addEventListener('click', toggleZoom);
        zoomable.push(image.parentNode.parentNode);
      } else {
        image.classList.remove(opts.zoomable_class);
        image.removeEventListener('click', toggleZoom);
      }
    }
    requested_animation_frame = false;
  };

  var toggleZoom = function (e) {
    e.preventDefault();
    for (var i = 0; i < zoomable.length; i++) {
      zoomable[i].classList.toggle(opts.zoom_class);
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
