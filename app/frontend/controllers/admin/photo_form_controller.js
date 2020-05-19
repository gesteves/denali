import { Controller } from 'stimulus';

/**
 * Controls the photo fields in the entry forms.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['thumbnail', 'position', 'fields', 'destroy'];

  /**
   * Removes the photo form from the page.
   * @param {Event} event A click event from the delete button.
   */
  delete (event) {
    event.preventDefault();
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
   * Sets the passed url as the src of the thumbnail img tag, and toggles the
   * fields to enter a caption. Marks the form as not empty so we can ask
   * for confirmation before deleting it.
   * @param {string} url An image's url.
   */
  setThumbnail (url) {
    this.thumbnailTarget.src = url;
    this.fieldsTargets.forEach(element => element.classList.toggle('is-hidden'));
    this.data.set('empty', 0);
  }

  /**
   * Reads the file selected in the file picker, and sets it as the thumbnail image.
   * @param {Event} event A change event from the file picker.
   */
  addFromFile (event) {
    const input = event.target;
    const files = input.files;

    if (!files[0].type.match(/jpe?g$/)) {
      return;
    }

    let reader = new FileReader();
    reader.addEventListener('load', e => this.setThumbnail(e.target.result));
    reader.readAsDataURL(files[0]);
  }

  /**
   * Convenient, self-explanatory function.
   * @param  {Event} event A click event
   */
  stopPropagation (event) {
    event.stopPropagation();
  }
}
