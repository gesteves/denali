import { Controller } from 'stimulus';
import LazyLoad from '../lib/lazy_load';

/**
 * Controls the lazy loading of images on the page.
 * @extends Controller
 */
export default class extends Controller {
  connect () {
    LazyLoad.observe(this.element);
  }
}
