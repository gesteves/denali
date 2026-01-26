import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';

// Track ClipboardJS calls
let clipboardOnCalls = [];

vi.mock('clipboard', () => ({
  default: class MockClipboardJS {
    constructor(element, options) {
      this.element = element;
      this.options = options;
      clipboardOnCalls = [];
    }
    on(event, handler) {
      clipboardOnCalls.push({ event, handler });
      return this;
    }
  }
}));

import ClipboardController from './clipboard_controller';

describe('ClipboardController', () => {
  let application;
  let element;

  beforeEach(() => {
    vi.clearAllMocks();

    document.body.innerHTML = `
      <div data-controller="clipboard">
        <input data-clipboard-target="source" value="Text to copy" readonly>
        <button data-clipboard-target="button" data-action="click->clipboard#preventDefault">
          <i class="fa fa-clipboard" data-clipboard-target="icon"></i>
          <span data-clipboard-target="label">Copy</span>
        </button>
      </div>
    `;

    element = document.querySelector('[data-controller="clipboard"]');
    application = Application.start();
    application.register('clipboard', ClipboardController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
    vi.clearAllMocks();
  });

  function getController() {
    return application.getControllerForElementAndIdentifier(element, 'clipboard');
  }

  function iconTarget() {
    return element.querySelector('[data-clipboard-target="icon"]');
  }

  function labelTarget() {
    return element.querySelector('[data-clipboard-target="label"]');
  }

  describe('connect', () => {
    it('sets up ClipboardJS with button target', () => {
      const controller = getController();
      // ClipboardJS should be initialized and handlers registered
      const successHandler = clipboardOnCalls.find(c => c.event === 'success');
      const errorHandler = clipboardOnCalls.find(c => c.event === 'error');
      expect(successHandler).toBeDefined();
      expect(errorHandler).toBeDefined();
    });
  });

  describe('preventDefault', () => {
    it('prevents default event behavior', () => {
      const controller = getController();
      const event = { preventDefault: vi.fn() };

      controller.preventDefault(event);

      expect(event.preventDefault).toHaveBeenCalled();
    });
  });

  describe('successfulCopy', () => {
    it('clears selection from event', () => {
      const controller = getController();
      const event = { clearSelection: vi.fn() };

      controller.successfulCopy(event);

      expect(event.clearSelection).toHaveBeenCalled();
    });

    it('changes icon class from clipboard to clipboard-check', () => {
      const controller = getController();
      const icon = iconTarget();
      const event = { clearSelection: vi.fn() };

      controller.successfulCopy(event);

      expect(icon.classList.contains('fa-clipboard')).toBe(false);
      expect(icon.classList.contains('fa-clipboard-check')).toBe(true);
    });

    it('updates label text to success message', () => {
      const controller = getController();
      const label = labelTarget();
      const event = { clearSelection: vi.fn() };

      controller.successfulCopy(event);

      expect(label.innerHTML).toBe('Copied to clipboard!');
    });

    it('handles missing label target gracefully', () => {
      // Remove label target
      labelTarget().remove();

      const controller = getController();
      const event = { clearSelection: vi.fn() };

      // Should not throw - the hasLabelTarget check should prevent the error
      expect(() => controller.successfulCopy(event)).not.toThrow();
    });
  });

  describe('unsuccessfulCopy', () => {
    it('updates label text to fallback message', () => {
      const controller = getController();
      const label = labelTarget();

      controller.unsuccessfulCopy();

      expect(label.innerHTML).toBe('Press Ctrl+C to copy!');
    });
  });
});
