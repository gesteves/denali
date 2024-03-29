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
    aspectRatio: String,
    cropX: Number,
    cropY: Number,
    cropWidth: Number,
    cropHeight: Number,
    focalX: Number,
    focalY: Number,
  }

  connect () {
    this.initializedCropper = false;
    this.csrfToken = document.querySelector('[name=csrf-token]').getAttribute('content');

    // If the image is loaded, initialize the cropper.
    if (this.photoTarget.complete && this.photoTarget.naturalWidth > 0 && this.photoTarget.naturalHeight > 0) {
      this.initializeCropper();
    }
  }

  /**
   * Initializes the Croppr library when the image loads.
   */
  initializeCropper () {
    this.cropper = new Croppr(this.photoTarget, {
      aspectRatio: this.calculateAspectRatio(this.aspectRatioValue),
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
    this.cropXValue = value.x;
    this.cropYValue = value.y;
    this.cropWidthValue = value.width;
    this.cropHeightValue = value.height;
    formData.append('crop[x]', value.x);
    formData.append('crop[y]', value.y);
    formData.append('crop[width]', value.width);
    formData.append('crop[height]', value.height);
    formData.append('crop[aspect_ratio]', this.aspectRatioValue);

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
    if ((this.cropWidthValue > 0) && (this.cropHeightValue > 0)) {
      const width = this.element.offsetWidth * this.cropWidthValue;
      const height = this.element.offsetHeight * this.cropHeightValue;
      const x = this.element.offsetWidth * this.cropXValue;
      const y = this.element.offsetHeight * this.cropYValue;
      cropper.resizeTo(width, height);
      cropper.moveTo(x, y);
    } else if ((this.focalXValue > 0) && (this.focalYValue > 0)) {
      const elementWidth = this.element.offsetWidth;
      const elementHeight = this.element.offsetHeight;
      const cropperWidth = elementWidth * cropper.getValue().width;
      const cropperHeight = elementHeight * cropper.getValue().height;
      const focalX = this.focalXValue * elementWidth;
      const focalY = this.focalYValue * elementHeight;
      const x = Math.min(Math.max(0, focalX - (cropperWidth/2)), elementWidth - cropperWidth);
      const y = Math.min(Math.max(0, focalY - (cropperHeight/2)), elementHeight - cropperHeight);
      cropper.moveTo(x, y);
    }
    this.initializedCropper = true;
  }

  /**
   * Attempts to convert an aspect ratio from a string to a number,
   * if it's represented as a ratio (e.g. 16:9).
   * @param {String} aspectRatio
   * @returns Float
   */
  calculateAspectRatio(aspectRatio) {
    let aspectRatioArray = aspectRatio.split(':');
    if (aspectRatioArray.length === 2) {
      let width = aspectRatioArray[0];
      let height = aspectRatioArray[1];
      return parseFloat(height)/parseFloat(width);
    } else {
      return parseFloat(aspectRatio);
    }
  }
}

