import { Controller } from 'stimulus';
import Masonry        from 'masonry-layout';

/**
 * Controls the Masonry grid on the page.
 * @extends Controller
 */
export default class extends Controller {
  connect () {
    // Do nothing if the browser supports native masonry!
    if (CSS.supports('grid-template-rows: masonry')) {
      return;
    }

    const itemSelector = this.data.get('item-selector') ? this.data.get('item-selector') : 'li';

    // Initialize Masonry.
    this.masonry = new Masonry(this.element, {
      initLayout: false,
      itemSelector: itemSelector,
      percentPosition: true,
      hiddenStyle: {
        opacity: 0
      },
      visibleStyle: {
        opacity: 1
      }
    });
    this.masonry.layout();

    // Set up a mutation observer to observe the grid container for any
    // changes in the `childList`, so that if any nodes get added to the container,
    // they get placed in the Masonry layout.
    this.observer = new MutationObserver(e => this.handleMutations(e));
    this.observer.observe(this.element, { childList: true });
  }

  /**
   * Gets the `childList` mutations, and inserts the added nodes into the
   * Masonry layout.
   * @param {MutationRecord[]} mutations An array of mutations.
   */
  handleMutations (mutations) {
    mutations
      .filter(mutation => mutation.type === 'childList')
      .forEach(mutation => this.masonry.appended(mutation.addedNodes));
  }
}
