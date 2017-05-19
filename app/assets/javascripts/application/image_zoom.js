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
        height,
        client_height = document.documentElement.clientHeight,
        client_width = document.documentElement.clientWidth;
    for (var i = 0; i < images.length; i++) {
      image = images[i];
      original_height = parseInt(image.getAttribute('data-height-original'));
      original_width = parseInt(image.getAttribute('data-width-original'));
      image_ratio = original_height/original_width;
      max_width = Math.min(original_width, client_width, opts.max_width);
      height = max_width * image_ratio;
      if (height > client_height) {
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

if (document.readyState !== 'loading') {
  Denali.ImageZoom.init();
} else {
  document.addEventListener('DOMContentLoaded', Denali.ImageZoom.init);
}
window.addEventListener('orientationchange', Denali.ImageZoom.init);
window.addEventListener('resize', Denali.ImageZoom.handleResize);
