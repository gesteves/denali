import { Controller } from 'stimulus';

/**
 * Controls the photo fields in the entry forms.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['thumbnail', 'focalmarker', 'position', 'focalx', 'focaly', 'fields', 'fileinput', 'destroy'];
  connect () {
    this.showFocalPoint();
  }


  /**
   * Positions the focal point marker on the correct position on top of the photo,
   * and displays it.
   */
  showFocalPoint () {
    if (!this.data.get('focal-x') || !this.data.get('focal-y')) {
      return;
    }

    const image_width  = this.thumbnailTarget.offsetWidth;
    const image_height = this.thumbnailTarget.offsetHeight;
    this.focalmarkerTarget.style.top  = `${(image_height * parseFloat(this.data.get('focal-y'))) - 50}px`;
    this.focalmarkerTarget.style.left = `${(image_width  * parseFloat(this.data.get('focal-x'))) - 50}px`;
    this.focalmarkerTarget.style.display = 'block';
  }


  /**
   * Calculates the focal point for the photo based on where the user clicked on
   * the thumbnail.
   * @param {Event} e A click event from the photo's thumbnail.
   */
  setFocalPoint (e) {
    e.preventDefault();
    const focal_x = (e.pageX - this.thumbnailTarget.getBoundingClientRect().left)/this.thumbnailTarget.offsetWidth;
    const focal_y = (e.pageY - this.thumbnailTarget.getBoundingClientRect().top)/this.thumbnailTarget.offsetHeight;

    this.data.set('focal-x', focal_x);
    this.data.set('focal-y', focal_y);
    this.focalxTarget.value = focal_x;
    this.focalyTarget.value = focal_y;

    this.showFocalPoint();
  }


  /**
   * Removes the photo form from the page.
   * @param {Event} e A click event from the delete button.
   */
  delete (e) {
    e.preventDefault();
    if (parseInt(this.data.get('empty')) || window.confirm('Are you sure you want to remove this photo?')) {
      if (this.hasDestroyTarget) {
        this.destroyTarget.value = 'true';
        this.element.style.display = 'none';
      } else {
        this.element.parentNode.removeChild(this.element);
      }
    }
  }

  /**
   * Triggers the file input, which is hidden on the page.
   * @param {Event} e A click event from a button (not the file input).
   */
  triggerFileInput (e) {
    e.preventDefault();
    this.fileinputTarget.click();
  }

  /**
   * Checks if the text entered on the input is an image, and if so, renders
   * is as a thumbnail.
   * @param {Event} e A keyup event from a text input.
   */
  addFromUrl (e) {
    const url = e.target.value;
    if (url.match(/\.jpe?g$/)) {
      this.setThumbnail(url);
    }
  }

  /**
   * Sets the passed url as the src of the thumbnail img tag, and toggles the
   * fields to enter a caption. Marks the form as not empty so we can ask
   * for confirmation before deleting it.
   * @param {string} url An image's url.
   */
  setThumbnail (url) {
    this.thumbnailTarget.src = url;
    this.fieldsTargets.forEach(e => e.classList.toggle('form__fields--hidden'));
    this.data.set('empty', 0);
  }

  /**
   * Reads the file selected in the file picker, and sets it as the thumbnail image.
   * @param {Event} e A change event from the file picker.
   */
  addFromFile (e) {
    const input = e.target;
    const files = input.files;

    if (!files[0].type.match(/\jpe?g$/)) {
      return;
    }

    let reader = new FileReader();
    reader.addEventListener('load', e => this.setThumbnail(e.target.result));
    reader.readAsDataURL(files[0]);
  }

  /**
   * Convenient, self-explanatory function.
   * @param  {Event} e A click event
   */
  stopPropagation (e) {
    e.stopPropagation();
  }
}
