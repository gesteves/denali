import 'intersection-observer';

let _observer;

export default class LazyLoad {
  static observe (element) {
    if (!element.getAttribute('data-lazy-loaded')) {
      observer().observe(element);
    }
  }
}

function observer () {
  if (!_observer) {
    IntersectionObserver.prototype.POLL_INTERVAL = 50;
    _observer = new IntersectionObserver((entries, observer) => handleIntersection(entries, observer), { rootMargin: '25%', threshold: 0 });
    // Enable polling on the polyfill to work around some Safari weirdness
    _observer.POLL_INTERVAL = 50;
  }
  return _observer;
}

function handleIntersection (entries, observer) {
  const intersecting = entries.filter(entry => {
    return (entry.intersectionRatio > 0 || entry.isIntersecting);
  });
  if (intersecting.length > 0) {
    loadIntersectingImages(intersecting, observer);
  }
}

function loadIntersectingImages (images, observer) {
  images.forEach(image => {
    loadImage(image.target);
    observer.unobserve(image.target);
  });
}

function loadImage (image) {
  if (image.hasAttribute('data-srcset') && typeof image.srcset !== 'undefined' && typeof image.sizes !== 'undefined') {
    image.setAttribute('srcset', image.getAttribute('data-srcset'));
    image.removeAttribute('data-srcset');
  } else if (image.hasAttribute('data-src')) {
    image.src = image.getAttribute('data-src');
    image.removeAttribute('data-src');
  }
  image.setAttribute('data-lazy-loaded', '');
}
