import 'intersection-observer';

class LazyLoad {
  constructor(elementsClass) {
    this.elementsClass = elementsClass;
    IntersectionObserver.prototype.POLL_INTERVAL = 50;
    this.observer = new IntersectionObserver(entries => this.handleIntersection(entries), { rootMargin: '25%', threshold: 0 });
    this.images = document.querySelectorAll(`.${this.elementsClass}`);
    for (let i = 0; i < this.images.length; i++) {
      let image = this.images[i];
      this.observer.observe(image);
    }
  }

  handleIntersection (entries) {
    let intersecting = entries.filter(entry => {
      return (entry.intersectionRatio > 0 || entry.isIntersecting);
    });
    if (intersecting.length > 0) {
      if ('requestAnimationFrame' in window) {
        requestAnimationFrame(() => this.loadIntersectingImages(intersecting));
      } else {
        this.loadIntersectingImages(intersecting);
      }
    }
  }

  loadIntersectingImages (images) {
    for (let i = 0; i < images.length; i++) {
      let image = images[i];
      this.loadImage(image.target);
      this.observer.unobserve(image.target);
    }
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

export default LazyLoad;
