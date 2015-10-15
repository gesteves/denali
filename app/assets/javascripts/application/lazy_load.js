var Denali = Denali || {};

Denali.LazyLoad = (function () {
  'use strict';

  var opts = {
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
        bottom;

    images = document.querySelectorAll('.' + opts.load_class);

    if (images.length === 0) {
      return;
    }

    bottom = window.scrollY + (window.innerHeight * 2);

    for (var i = 0; i < images.length; i++) {
      image = images[i];
      image_top = image.getBoundingClientRect().top;
      if (image_top <= bottom) {
        loadImage(image);
      }
    }

    picturefill();
    requested_animation_frame = false;
  };

  var loadImage = function (image) {
    if (image.hasAttribute('data-srcset')) {
      image.setAttribute('srcset', image.getAttribute('data-srcset'));
      image.removeAttribute('data-srcset');
    }
    image.classList.remove(opts.load_class);
  };

  return {
    loadImages : loadImages,
    handleScroll : handleScroll
  };
})();
