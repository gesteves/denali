'use strict';

class ImageZoom {
  constructor (opts = {}) {
    const options = Object.assign({
      imagesSelector: '.entry__photo',
      zoomableClass: 'entry__photo--zoomable',
      zoomClass: 'entry__photo-container--zoom',
      maxWidth: 1680
    }, opts);
    this.zoomable = [];
    this.zoomClass = options.zoomClass;
    let originalWidth,
        originalHeight,
        imageRatio,
        height,
        clientHeight = document.documentElement.clientHeight,
        clientWidth = document.documentElement.clientWidth,
        maxWidth,
        imageContainer,
        images = document.querySelectorAll(options.imagesSelector);

    images.forEach(image => {
      originalHeight = parseInt(image.getAttribute('data-height-original'));
      originalWidth = parseInt(image.getAttribute('data-width-original'));
      imageRatio = originalHeight/originalWidth;
      maxWidth = Math.min(originalWidth, clientWidth, options.maxWidth);
      height = maxWidth * imageRatio;
      imageContainer = image.parentNode.parentNode;
      if (height > clientHeight) {
        image.classList.add(options.zoomableClass);
        image.addEventListener('click', e => this.toggleZoom(e));
        this.zoomable.push(imageContainer);
      }
    });
  }

  toggleZoom (e) {
    e.preventDefault();
    this.zoomable.forEach(image => image.classList.toggle(this.zoomClass));
  }
}

if (document.readyState !== 'loading') {
  new ImageZoom();
} else {
  document.addEventListener('DOMContentLoaded', () => {
    new ImageZoom();
  });
}
