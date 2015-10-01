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
    requestAnimationFrame(lazyLoad);
  };

  var lazyLoad = function () {
    var image,
        image_top,
        image_bottom;
    var images = document.querySelectorAll(opts.images);
    var top = window.scrollY;
    var bottom = top + window.innerHeight;
    for (var i = 0; i < images.length; i++) {
      image = images[i];
      image_top = image.getBoundingClientRect().top;
      image_bottom = image.getBoundingClientRect().bottom;
      if ((image_top <= bottom) && (image_bottom >= top)) {
        loadImage(image);
      }
    }
    requested_animation_frame = false;
  };

  var loadImage = function (image) {
    var src = image.getAttribute('data-src');
    var srcset = image.getAttribute('data-srcset');
    image.setAttribute('src', src);
    image.setAttribute('srcset', srcset);
    image.removeAttribute('data-src');
    image.removeAttribute('data-srcset');
    image.classList.remove(opts.load_class);
  };

  return {
    lazyLoad : lazyLoad,
    handleScroll : handleScroll
  };
})();
