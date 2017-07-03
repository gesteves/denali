'use strict';

class ImageZoom {
  constructor (imagesSelector, zoomableClass, zoomClass, maxWidth = 1680) {
    this.zoomable = [];
    this.zoomClass = zoomClass;
    let originalWidth,
        originalHeight,
        imageRatio,
        height,
        clientHeight = document.documentElement.clientHeight,
        clientWidth = document.documentElement.clientWidth,
        images = document.querySelectorAll(imagesSelector);

    images.forEach(image => {
      originalHeight = parseInt(image.getAttribute('data-height-original'));
      originalWidth = parseInt(image.getAttribute('data-width-original'));
      imageRatio = originalHeight/originalWidth;
      maxWidth = Math.min(originalWidth, clientWidth, maxWidth);
      height = maxWidth * imageRatio;
      if (height > clientHeight) {
        image.classList.add(zoomableClass);
        image.addEventListener('click', e => this.toggleZoom(e));
        this.zoomable.push(image.parentNode.parentNode);
      }
    });
  }

  toggleZoom (e) {
    e.preventDefault();
    this.zoomable.forEach(image => image.classList.toggle(this.zoomClass));
  }
}

if (document.readyState !== 'loading') {
  new ImageZoom('.entry__photo', 'entry__photo--zoomable', 'entry__photo-container--zoom');
} else {
  document.addEventListener('DOMContentLoaded', () => {
    new ImageZoom('.entry__photo', 'entry__photo--zoomable', 'entry__photo-container--zoom');
  });
}
