import { Controller } from 'stimulus';
import Masonry        from 'masonry-layout';

/**
 * Controls the Masonry grid on the page.
 * @extends Controller
 */
export default class extends Controller {
  /**
   * Initializes a Masonry layout, and instantiates a MutationObserver to
   * place any new inserted nodes into the layout.
   */
  connect () {
    const selector = this.data.get('selector') ? this.data.get('selector') : 'li';
    this.masonry = new Masonry(this.element, {
      initLayout: false,
      itemSelector: selector,
      percentPosition: true,
      hiddenStyle: {
        opacity: 0
      },
      visibleStyle: {
        opacity: 1
      }
    });
    this.masonry.layout();
    this.observer = new MutationObserver(e => this.placeAddedNodes(e));
    this.observer.observe(this.element, { childList: true });
  }

  /**
   * Gets the `childList` mutations, and inserts the added nodes into the
   * Masonry layout.
   * @param {MutationRecord[]} mutations An array of mutations.
   */
  placeAddedNodes (mutations) {
    mutations
      .filter(mutation => mutation.type === 'childList')
      .forEach(mutation => this.masonry.appended(mutation.addedNodes));
  }
}
