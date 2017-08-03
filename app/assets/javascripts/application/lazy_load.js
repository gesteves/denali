//= require intersection-observer/intersection-observer

'use strict';
class LazyLoad {
  constructor(elementsClass) {
    this.elementsClass = elementsClass;
    IntersectionObserver.prototype.POLL_INTERVAL = 50;
    this.observer = new IntersectionObserver(entries => this.handleIntersection(entries), { rootMargin: '200px', threshold: 0 });
    this.images = document.querySelectorAll(`.${this.elementsClass}`);
    this.images.forEach(image => this.observer.observe(image));
  }

  handleIntersection (entries) {
    entries.forEach(entry => {
      if (entry.intersectionRatio > 0 || entry.isIntersecting) {
        this.loadImage(entry.target);
        this.observer.unobserve(entry.target);
      }
    });
  }

  loadImage (image) {
    if (image.hasAttribute('data-srcset') && typeof image.srcset !== 'undefined' && typeof image.sizes !== 'undefined') {
      image.setAttribute('srcset', image.getAttribute('data-srcset'));
      image.removeAttribute('data-srcset');
    } else if (image.hasAttribute('data-src')) {
      image.src = image.getAttribute('data-src');
      image.removeAttribute('data-src');
    }
    image.classList.remove(this.elementsClass);
  }
}

if (document.readyState !== 'loading') {
  new LazyLoad('js-lazy-load');
} else {
  document.addEventListener('DOMContentLoaded', () => new LazyLoad('js-lazy-load'));
}
