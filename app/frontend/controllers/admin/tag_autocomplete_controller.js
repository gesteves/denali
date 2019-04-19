import { Controller } from 'stimulus';
import Awesomplete from 'awesomplete';

/**
 * Controls the entry form.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['tags', 'datalist'];

  /**
   * Sets up the tag autocomplete.
   */
  connect () {
    new Awesomplete(this.tagsTarget, {
      list: this.datalistTarget,
      filter: function (text, input) {
        return Awesomplete.FILTER_CONTAINS(text, input.match(/[^,]*$/)[0]);
      },
      replace: function (text) {
        var before = this.input.value.match(/^.+,\s*|/)[0];
        this.input.value = `${before}${text}, `;
      }
    });
  }
}
