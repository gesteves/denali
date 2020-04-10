import 'intersection-observer';

let _observer;

/**
 * Controls the lazy loading of images on the page.
 */
export default class LazyLoad {
  static observe (element) {
    if ('loading' in HTMLImageElement.prototype) {
      loadImage(element);
    } else if (!element.getAttribute('data-lazy-loaded')) {
      observer().observe(element);
    }
  }

  static unobserve (element) {
    observer().unobserve(element);
  }
}

/**
 * Return or instantiate an IntersectionObserver to use in the static function.
 * @return {IntersectionObserver} An intersection observer.
 */
function observer () {
  if (!_observer) {
    IntersectionObserver.prototype.POLL_INTERVAL = 50;
    _observer = new IntersectionObserver(handleIntersection, { rootMargin: '25%', threshold: 0 });
    // Enable polling on the polyfill to work around some Safari weirdness
    _observer.POLL_INTERVAL = 50;
  }
  return _observer;
}

/**
 * Handler for the class's IntersectionObserver.
 * @param  {IntersectionObserverEntry[]} entries An array of photos.
 */
function handleIntersection (entries) {
  const intersecting = entries.filter(entry => {
    return (entry.intersectionRatio > 0 || entry.isIntersecting);
  });
  requestAnimationFrame(() => {
    intersecting.forEach(entry => {
      loadImage(entry.target);
      observer().unobserve(entry.target);
    });
  });
}

/**
 * Lazy load the image, by replacing the srcset or src attributes with the
 * data-srcset or data-src attributes on the element.
 * @param  {Element} image The <img> element for the image.
 */
function loadImage (image) {
  if (image.hasAttribute('data-srcset') && typeof image.srcset !== 'undefined' && typeof image.sizes !== 'undefined') {
    image.sizes = image.getAttribute('data-sizes');
    image.removeAttribute('data-sizes');
    image.srcset = image.getAttribute('data-srcset');
    image.removeAttribute('data-srcset');
  } else if (image.hasAttribute('data-src')) {
    image.src = image.getAttribute('data-src');
    image.removeAttribute('data-src');
  }
  image.setAttribute('data-lazy-loaded', '');
}
