import { Controller } from 'stimulus';

export default class extends Controller {
  static targets = ['photo'];

  connect () {
    this.photoTargets.forEach(p => this.checkIfZoomable(p));
  }

  checkIfZoomable (photo) {
    const clientHeight = document.documentElement.clientHeight;
    const clientWidth = document.documentElement.clientWidth;
    const originalHeight = parseInt(photo.getAttribute('data-photo-height'));
    const originalWidth = parseInt(photo.getAttribute('data-photo-width'));
    const imageRatio = originalHeight/originalWidth;
    const maxWidth = Math.min(originalWidth, clientWidth, parseInt(this.data.get('maxWidth')));
    const height = maxWidth * imageRatio;
    if (height > clientHeight) {
      photo.classList.add('entry__photo--zoomable');
      photo.setAttribute('data-photo-zoomable', 1);
    }
  }

  zoom () {
    this.photoTargets.forEach(photo => {
      if (photo.getAttribute('data-photo-zoomable') === '1') {
        let container = photo.parentNode.parentNode;
        container.classList.toggle('entry__photo-container--zoom');
      }
    });
  }
}
