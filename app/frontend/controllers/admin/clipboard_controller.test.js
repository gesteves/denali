import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';
import ClipboardController from './clipboard_controller';

describe('ClipboardController', () => {
  let application;
  let element;

  beforeEach(() => {
    vi.clearAllMocks();

    Object.assign(navigator, {
      clipboard: {
        writeText: vi.fn(() => Promise.resolve())
      }
    });

    document.body.innerHTML = `
      <div data-controller="clipboard">
        <input data-clipboard-target="source" value="Text to copy" readonly>
        <button data-clipboard-target="button">
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

  function buttonTarget() {
    return element.querySelector('[data-clipboard-target="button"]');
  }

  function iconTarget() {
    return element.querySelector('[data-clipboard-target="icon"]');
  }

  function labelTarget() {
    return element.querySelector('[data-clipboard-target="label"]');
  }

  describe('connect', () => {
    it('adds a click handler to the button', () => {
      const controller = getController();
      expect(controller).toBeDefined();
      // The button should have a click listener attached
      // We verify this indirectly through the copy tests
    });
  });

  describe('disconnect', () => {
    it('removes the click listener from the button', () => {
      const controller = getController();
      const button = buttonTarget();
      const removeSpy = vi.spyOn(button, 'removeEventListener');

      controller.disconnect();

      expect(removeSpy).toHaveBeenCalledWith('click', controller.handleClick);
    });

    it('no longer triggers copy after disconnect', async () => {
      const controller = getController();
      controller.disconnect();

      buttonTarget().click();
      await new Promise(resolve => setTimeout(resolve, 10));

      expect(navigator.clipboard.writeText).not.toHaveBeenCalled();
    });
  });

  describe('copy via button click', () => {
    it('calls navigator.clipboard.writeText with source value', async () => {
      buttonTarget().click();
      await vi.waitFor(() => {
        expect(navigator.clipboard.writeText).toHaveBeenCalledWith('Text to copy');
      });
    });

    it('changes icon class on successful copy', async () => {
      buttonTarget().click();
      await vi.waitFor(() => {
        expect(iconTarget().classList.contains('fa-clipboard')).toBe(false);
        expect(iconTarget().classList.contains('fa-clipboard-check')).toBe(true);
      });
    });

    it('updates label text on successful copy', async () => {
      buttonTarget().click();
      await vi.waitFor(() => {
        expect(labelTarget().innerHTML).toBe('Copied to clipboard!');
      });
    });

    it('handles missing label target gracefully on success', async () => {
      labelTarget().remove();
      buttonTarget().click();
      await vi.waitFor(() => {
        expect(navigator.clipboard.writeText).toHaveBeenCalledWith('Text to copy');
      });
      // Should not throw
    });
  });

  describe('unsuccessfulCopy', () => {
    it('updates label text to fallback message on failure', async () => {
      navigator.clipboard.writeText = vi.fn(() => Promise.reject(new Error('fail')));
      buttonTarget().click();
      await vi.waitFor(() => {
        expect(labelTarget().innerHTML).toBe('Press Ctrl+C to copy!');
      });
    });
  });
});
