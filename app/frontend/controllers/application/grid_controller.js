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
      transitionDuration: 0
    });

    this.masonry.layout();

    // Set up a mutation observer to observe the grid container for any
    // changes in the `childList`, so that if any nodes get added to the container,
    // they get placed in the Masonry layout.
    this.mutationObserver = new MutationObserver(e => this.handleMutations(e));
    this.mutationObserver.observe(this.element, { childList: true });

    // Set up a resize observer to work around a weird race condition in Safari,
    // which causes the masonry to be set up (incorrectly) before styles are applied.
    // When the styles load, the element should resize and call `masonry.layout()` again.
    if ('ResizeObserver' in window) {
      this.resizeObserver = new ResizeObserver(() => {
        this.masonry.layout();
      });
      this.resizeObserver.observe(this.element);
    }
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
