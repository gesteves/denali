import { Controller } from 'stimulus';
import { fetchStatus, fetchJson, sendNotification } from '../../lib/utils';
import Croppr from 'croppr';

/**
 * Controls cropping photos.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['photo'];
  static values = {
    endpoint: String,
    aspectRatio: Number,
    field: String,
    crop: Object
  }

  connect () {
    this.initializedCropper = false;
    this.csrfToken = document.querySelector('[name=csrf-token]').getAttribute('content');
  }

  /**
   * Initializes the Croppr library when the image loads.
   */
  initializeCropper () {
    this.cropper = new Croppr(this.photoTarget, {
      aspectRatio: this.aspectRatioValue,
      returnMode: 'ratio',
      onCropEnd: (value) => this.updateCrop(value),
      onInitialize: (cropper) => {
        this.fixCropperOverlay();
        this.setInitialCropperPosition(cropper);
      }
    });
  }

  /**
   * Updates the crop in the backend.
   * @param {Object} value the crop data returned by the library.
   */
  updateCrop (value) {
    if (!this.initializedCropper) {
      return;
    }

    let formData = new FormData();
    this.cropValue = value;
    formData.append(`photo[${this.fieldValue}]`, JSON.stringify(value));

    const fetchOpts = {
      method: 'POST',
      headers: new Headers({
        'X-CSRF-Token': this.csrfToken
      }),
      credentials: 'include',
      body: formData
    };

    fetch(this.endpointValue, fetchOpts)
      .then(fetchStatus)
      .then(fetchJson)
      .then(json => sendNotification(json.message, json.status));
  }

  /**
   * Toggles visibility of the clipped image to work around a rendering issue that
   * prevents the overlay from being visible.
   */
  fixCropperOverlay () {
    let image = this.element.querySelector('.croppr-imageClipped');
    image.style.display = 'none';
    requestAnimationFrame(() => image.style.display = 'block');
  }

  /**
   * Sets the initial position of the cropped tool, if there's crop data for this instance.
   * @param {Croppr} cropper an instance of the Croppr library
   */
  setInitialCropperPosition (cropper) {
    if (('x' in this.cropValue) && ('y' in this.cropValue) && ('width' in this.cropValue) && ('height' in this.cropValue)) {
      const width = this.element.offsetWidth * this.cropValue.width;
      const height = this.element.offsetHeight * this.cropValue.height;
      const x = this.element.offsetWidth * this.cropValue.x;
      const y = this.element.offsetHeight * this.cropValue.y;
      cropper.resizeTo(width, height);
      cropper.moveTo(x, y);
    }
    this.initializedCropper = true;
  }
}

