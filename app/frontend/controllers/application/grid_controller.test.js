import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';

// Track Masonry calls
let masonryLayoutCalled = false;
let masonryAppendedCalls = [];
let masonryOptions = {};
let masonryDestroyCalled = false;

vi.mock('masonry-layout', () => ({
  default: class MockMasonry {
    constructor(element, options) {
      this.element = element;
      this.options = options;
      masonryOptions = options;
    }
    layout() {
      masonryLayoutCalled = true;
    }
    appended(nodes) {
      masonryAppendedCalls.push(nodes);
    }
    destroy() {
      masonryDestroyCalled = true;
    }
  }
}));

import GridController from './grid_controller';

describe('GridController', () => {
  let application;
  let element;
  let originalCSS;

  beforeEach(() => {
    masonryLayoutCalled = false;
    masonryAppendedCalls = [];
    masonryOptions = {};
    masonryDestroyCalled = false;

    // Save original CSS.supports
    originalCSS = global.CSS;

    // Mock CSS.supports to return false for grid-lanes (so Masonry is used)
    global.CSS = {
      supports: vi.fn(() => false)
    };

    // Mock ResizeObserver
    global.ResizeObserver = class MockResizeObserver {
      constructor(callback) {
        this.callback = callback;
      }
      observe() {}
      unobserve() {}
      disconnect() { this._disconnected = true; }
    };

    // Mock MutationObserver
    global.MutationObserver = class MockMutationObserver {
      constructor(callback) {
        this.callback = callback;
      }
      observe() {}
      disconnect() { this._disconnected = true; }
      takeRecords() { return []; }
    };

    document.body.innerHTML = `
      <ul data-controller="grid" data-grid-item-selector-value=".grid-item">
        <li class="grid-item">Item 1</li>
        <li class="grid-item">Item 2</li>
        <li class="grid-item">Item 3</li>
      </ul>
    `;

    element = document.querySelector('[data-controller="grid"]');
    application = Application.start();
    application.register('grid', GridController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
    vi.clearAllMocks();
    global.CSS = originalCSS;
  });

  function getController() {
    return application.getControllerForElementAndIdentifier(element, 'grid');
  }

  describe('connect', () => {
    it('checks CSS.supports for native masonry', () => {
      // The CSS.supports mock returns false, so Masonry is initialized
      const controller = getController();
      expect(controller.masonry).toBeDefined();
      expect(global.CSS.supports).toHaveBeenCalled();
    });

    it('initializes Masonry with element', () => {
      const controller = getController();
      expect(controller.masonry).toBeDefined();
    });

    it('uses itemSelectorValue for Masonry itemSelector', () => {
      expect(masonryOptions.itemSelector).toBe('.grid-item');
    });

    it('uses itemSelector from options', () => {
      // Already initialized with '.grid-item' from beforeEach
      expect(masonryOptions.itemSelector).toBe('.grid-item');
    });

    it('configures Masonry with percentPosition', () => {
      expect(masonryOptions.percentPosition).toBe(true);
    });

    it('configures Masonry with no transition duration', () => {
      expect(masonryOptions.transitionDuration).toBe(0);
    });

    it('calls layout after initialization', () => {
      expect(masonryLayoutCalled).toBe(true);
    });

    it('sets up MutationObserver', () => {
      const controller = getController();
      expect(controller.mutationObserver).toBeDefined();
    });

    it('sets up ResizeObserver when available', () => {
      const controller = getController();
      expect(controller.resizeObserver).toBeDefined();
    });
  });

  describe('handleMutations', () => {
    it('appends added element nodes to Masonry', () => {
      const controller = getController();
      masonryAppendedCalls = [];

      const li = document.createElement('li');
      const mutations = [
        {
          type: 'childList',
          addedNodes: [li]
        }
      ];

      controller.handleMutations(mutations);

      expect(masonryAppendedCalls.length).toBe(1);
      expect(masonryAppendedCalls[0]).toEqual([li]);
    });

    it('filters out text nodes from addedNodes', () => {
      const controller = getController();
      masonryAppendedCalls = [];

      const textNode = document.createTextNode('  ');
      const li = document.createElement('li');
      const mutations = [
        {
          type: 'childList',
          addedNodes: [textNode, li]
        }
      ];

      controller.handleMutations(mutations);

      expect(masonryAppendedCalls.length).toBe(1);
      expect(masonryAppendedCalls[0]).toEqual([li]);
    });

    it('does not call appended when only text nodes are added', () => {
      const controller = getController();
      masonryAppendedCalls = [];

      const textNode = document.createTextNode('\n');
      const mutations = [
        {
          type: 'childList',
          addedNodes: [textNode]
        }
      ];

      controller.handleMutations(mutations);

      expect(masonryAppendedCalls.length).toBe(0);
    });

    it('ignores non-childList mutations', () => {
      const controller = getController();
      masonryAppendedCalls = [];

      const mutations = [
        {
          type: 'attributes',
          addedNodes: []
        }
      ];

      controller.handleMutations(mutations);

      expect(masonryAppendedCalls.length).toBe(0);
    });

    it('handles multiple childList mutations', () => {
      const controller = getController();
      masonryAppendedCalls = [];

      const mutations = [
        { type: 'childList', addedNodes: [document.createElement('li')] },
        { type: 'childList', addedNodes: [document.createElement('li')] }
      ];

      controller.handleMutations(mutations);

      expect(masonryAppendedCalls.length).toBe(2);
    });

    it('filters out non-childList mutations from mixed array', () => {
      const controller = getController();
      masonryAppendedCalls = [];

      const mutations = [
        { type: 'childList', addedNodes: [document.createElement('li')] },
        { type: 'attributes', addedNodes: [] },
        { type: 'childList', addedNodes: [document.createElement('li')] }
      ];

      controller.handleMutations(mutations);

      expect(masonryAppendedCalls.length).toBe(2);
    });
  });

  describe('with ResizeObserver', () => {
    it('sets up ResizeObserver when available', () => {
      const controller = getController();
      // ResizeObserver is mocked in beforeEach, so it should be defined
      expect(controller.resizeObserver).toBeDefined();
    });
  });

  describe('disconnect', () => {
    it('disconnects the MutationObserver', () => {
      const controller = getController();
      controller.disconnect();
      expect(controller.mutationObserver._disconnected).toBe(true);
    });

    it('disconnects the ResizeObserver', () => {
      const controller = getController();
      controller.disconnect();
      expect(controller.resizeObserver._disconnected).toBe(true);
    });

    it('destroys the Masonry instance', () => {
      getController();
      masonryDestroyCalled = false;
      const controller = getController();
      controller.disconnect();
      expect(masonryDestroyCalled).toBe(true);
    });

    it('does not throw when native CSS masonry was used (no observers)', async () => {
      application.stop();

      global.CSS = { supports: vi.fn(() => true) };

      document.body.innerHTML = `
        <ul data-controller="grid">
          <li class="grid-item">Item 1</li>
        </ul>
      `;

      element = document.querySelector('[data-controller="grid"]');
      application = Application.start();
      application.register('grid', GridController);

      await new Promise(resolve => setTimeout(resolve, 0));

      const controller = getController();
      expect(() => controller.disconnect()).not.toThrow();
    });
  });

  describe('native CSS masonry support', () => {
    it('does not create Masonry instance when CSS supports grid-lanes', async () => {
      application.stop();
      masonryLayoutCalled = false;

      global.CSS = { supports: vi.fn(() => true) };

      document.body.innerHTML = `
        <ul data-controller="grid">
          <li class="grid-item">Item 1</li>
        </ul>
      `;

      element = document.querySelector('[data-controller="grid"]');
      application = Application.start();
      application.register('grid', GridController);

      await new Promise(resolve => setTimeout(resolve, 0));

      const controller = getController();
      expect(controller.masonry).toBeUndefined();
      expect(controller.mutationObserver).toBeUndefined();
      expect(controller.resizeObserver).toBeUndefined();
      expect(masonryLayoutCalled).toBe(false);
    });
  });

  describe('ResizeObserver callback', () => {
    it('calls masonry.layout() when ResizeObserver fires', async () => {
      let resizeCallback;
      global.ResizeObserver = class {
        constructor(callback) {
          resizeCallback = callback;
        }
        observe() {}
        unobserve() {}
        disconnect() {}
      };

      application.stop();
      document.body.innerHTML = `
        <ul data-controller="grid">
          <li class="grid-item">Item 1</li>
        </ul>
      `;

      element = document.querySelector('[data-controller="grid"]');
      application = Application.start();
      application.register('grid', GridController);

      await new Promise(resolve => setTimeout(resolve, 0));

      // Reset after initial layout call
      masonryLayoutCalled = false;

      resizeCallback();
      expect(masonryLayoutCalled).toBe(true);
    });
  });
});
