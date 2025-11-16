import { Controller } from 'stimulus';

/**
 * Controls the Instagram Stories preview, switching between cropped and uncropped images.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['preview', 'checkbox'];
  static values = {
    croppedUrl: String,
    uncroppedUrl: String
  }

  /**
   * Updates the preview image based on whether the crop checkbox is checked.
   * @param {Event} event A change event from the checkbox.
   */
  updatePreview(event) {
    const isChecked = event.target.checked;
    this.previewTarget.src = isChecked ? this.croppedUrlValue : this.uncroppedUrlValue;
  }
}

