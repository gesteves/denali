'use strict';

class ImageZoom {
  constructor(selector = '.entry__image') {
    var images = document.querySelectorAll(selector);
    var image;
    for (var i = 0; i < images.length; i++) {
      image = images[i];
      image.addEventListener('load', (e) => this.setUpClickHandler(e));
    }
  }

  setUpClickHandler(e) {
    var image = e.currentTarget;
    var height = image.offsetHeight;
    if (height >= window.innerHeight) {
      image.classList.add('entry__image--zoomable');
      image.addEventListener('click', (e) => this.toggleZoom(e));
    }
  }

  toggleZoom(e) {
    e.preventDefault();
    e.currentTarget.classList.toggle('entry__image--fit');
  }
}

export default ImageZoom;
