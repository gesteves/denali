var Denali = Denali || {};

Denali.LazyLoad = (function () {
  'use strict';

  var opts = {
    load_class : 'js-lazy-load'
  };

  var requested_animation_frame = false;
  var observer;

  var init = function () {
    var images = document.querySelectorAll('.' + opts.load_class);
    if (typeof IntersectionObserver === 'undefined') {
      document.addEventListener('scroll', handleScroll);
      loadImages();
    } else {
      observer = new IntersectionObserver(handleIntersection);
      for (var i = 0; i < images.length; i++) {
        observer.observe(images[i]);
      }
    }
    hideImages(images);
  };

  var handleIntersection = function (entries) {
    entries.forEach(function (entry) {
      loadImage(entry.target);
      observer.unobserve(entry.target);
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
    viewport_height = document.documentElement.clientHeight;
    if (images.length === 0) {
      document.removeEventListener('scroll', handleScroll);
      return;
    }

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
    if (image.hasAttribute('data-srcset') && typeof image.srcset !== 'undefined') {
      image.setAttribute('srcset', image.getAttribute('data-srcset'));
      image.removeAttribute('data-srcset');
    } else if (image.hasAttribute('data-src')) {
      image.src = image.getAttribute('data-src');
      image.removeAttribute('data-src');
    }
    image.classList.remove(opts.load_class);
  };

  var hideImages = function (images) {
    var image;
    for (var i = 0; i < images.length; i++) {
      image = images[i];
      image.style.opacity = 0;
      image.addEventListener('load', showImage);
    }
  };

  var showImage = function (event) {
    event.target.style.opacity = 1;
  };

  return {
    init : init
  };
})();
