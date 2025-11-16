import { Controller } from 'stimulus';

/**
 * Controls the Instagram Story preview in the modal, updating the thumbnail
 * when the crop checkbox is toggled.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['thumbnail', 'checkbox'];
  static values = {
    croppedUrl: String,
    uncroppedUrl: String
  }

  /**
   * Updates the thumbnail image when the crop checkbox is toggled.
   * @param {Event} event A change event from the checkbox.
   */
  updateThumbnail (event) {
    const isCropped = event.target.checked;
    this.thumbnailTarget.src = isCropped ? this.croppedUrlValue : this.uncroppedUrlValue;
  }
}

