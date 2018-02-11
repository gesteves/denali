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

  triggerFileInput (e) {
    e.preventDefault();
    this.fileinputTarget.click();
  }

  addFromUrl (e) {
    const url = e.target.value;
    if (url.match(/\.jpe?g$/)) {
      this.setThumbnail(url);
    }
  }

  setThumbnail (url) {
    this.thumbnailTarget.src = url;
    this.fieldsTargets.forEach(e => e.classList.toggle('form__fields--hidden'));
    this.data.set('empty', 0);
  }

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

  stopPropagation (e) {
    e.stopPropagation();
  }
}
