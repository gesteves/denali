var Denali = Denali || {};

Denali.LazyLoad = (function () {
  'use strict';

  var opts = {
    load_class : 'js-lazy-load',
    threshold: 0
  };
  var observer;

  var init = function () {
    var image, i;
    var images = document.querySelectorAll('.' + opts.load_class);
    if (typeof observer === 'undefined') {
      observer = new IntersectionObserver(handleIntersection, { rootMargin: opts.threshold + 'px' });
    }
    for (i = 0; i < images.length; i++) {
      image = images[i];
      observer.observe(image);
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
