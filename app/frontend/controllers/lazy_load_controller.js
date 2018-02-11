import { Controller } from 'stimulus';
import LazyLoad from '../observers/lazy_load';

/**
 * Controls the lazy loading of images on the page.
 * @extends Controller
 */
export default class extends Controller {
  connect () {
    LazyLoad.observe(this.element);
  }

  disconnect () {
    LazyLoad.unobserve(this.element);
  }
}
