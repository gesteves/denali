import { Controller } from 'stimulus';
import Pagination from '../../observers/pagination';

/**
 * Controls updating the browser bar while scrolling through a list of entries.
 * @extends Controller
 */
export default class extends Controller {
  connect () {
    Pagination.observe(this.element);
  }

  disconnect () {
    Pagination.unobserve(this.element);
  }
}
