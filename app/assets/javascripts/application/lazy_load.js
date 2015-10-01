var Denali = Denali || {};

Denali.LazyLoad = (function () {
  'use strict';

  var opts = {
    images     : '.js-lazy-load',
    load_class : 'js-lazy-load'
  };

  var requested_animation_frame = false;

  var handleScroll = function () {
    if (requested_animation_frame) {
      return;
    }
    requested_animation_frame = true;
    requestAnimationFrame(loadImages);
  };

  var loadImages = function () {
    var image,
        images,
        image_top,
        image_bottom,
        top,
        bottom;

    images = document.querySelectorAll(opts.images);

    if (images.length === 0) {
      return;
    }

    top = window.scrollY;
    bottom = top + window.innerHeight;

    for (var i = 0; i < images.length; i++) {
      image = images[i];
      image_top = image.getBoundingClientRect().top;
      image_bottom = image.getBoundingClientRect().bottom;
      if ((image_top <= bottom) && (image_bottom >= top)) {
        loadImage(image);
      }
    }

    if ((typeof picturefill !== 'undefined')) {
      picturefill();
    }

    requested_animation_frame = false;
  };

  var loadImage = function (image) {
    if (image.hasAttribute('data-src')) {
      image.src = image.getAttribute('data-src');
    }
    if (image.hasAttribute('data-srcset')) {
      image.setAttribute('srcset', image.getAttribute('data-srcset'));
    }
    image.classList.remove(opts.load_class);
  };

  return {
    loadImages : loadImages,
    handleScroll : handleScroll
  };
})();
