var Denali = Denali || {};

Denali.LazyLoad = (function () {
  'use strict';

  var opts = {
    load_class : 'js-lazy-load'
  };

  var requested_animation_frame = false;
  var observer;

  var init = function () {
    var image, i;
    var images = document.querySelectorAll('.' + opts.load_class);
    if (typeof IntersectionObserver === 'undefined') {
      document.addEventListener('scroll', handleScroll);
      loadImages();
    } else {
      if (typeof observer === 'undefined') {
        observer = new IntersectionObserver(handleIntersection);
      }
      for (i = 0; i < images.length; i++) {
        image = images[i];
        observer.observe(image);
      }
    }
  };

  var handleIntersection = function (entries) {
    entries.forEach(function (entry) {
      if (entry.intersectionRatio > 0 || entry.isIntersecting) {
        loadImage(entry.target);
        observer.unobserve(entry.target);
      }
    });
  };

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
        viewport_height;

    images = document.querySelectorAll('.' + opts.load_class);

    if (images.length === 0) {
      document.removeEventListener('scroll', handleScroll);
      return;
    }

    viewport_height = document.documentElement.clientHeight;

    for (var i = 0; i < images.length; i++) {
      image = images[i];
      image_top = image.getBoundingClientRect().top;
      if (image_top <= viewport_height) {
        loadImage(image);
      }
    }

    requested_animation_frame = false;
  };

  var loadImage = function (image) {
    if (image.hasAttribute('data-srcset') && typeof image.srcset !== 'undefined' && typeof image.sizes !== 'undefined') {
      image.setAttribute('srcset', image.getAttribute('data-srcset'));
      image.removeAttribute('data-srcset');
    } else if (image.hasAttribute('data-src')) {
      image.src = image.getAttribute('data-src');
      image.removeAttribute('data-src');
    }
    image.classList.remove(opts.load_class);
  };

  return {
    init : init
  };
})();

if (document.readyState !== 'loading') {
  Denali.LazyLoad.init();
} else {
  document.addEventListener('DOMContentLoaded', Denali.LazyLoad.init);
}
