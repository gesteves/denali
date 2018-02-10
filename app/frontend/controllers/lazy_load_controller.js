import { Controller } from 'stimulus';
import LazyLoad from '../lib/lazy_load';

export default class extends Controller {
  connect () {
    LazyLoad.observe(this.element);
  }
}
