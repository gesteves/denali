import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';

// Mock the utils module before importing the controller
const mockSupportsHover = vi.fn(() => false);
vi.mock('../../lib/utils', () => ({
  supportsHover: () => mockSupportsHover()
}));

import DropdownController from './dropdown_controller';

describe('DropdownController', () => {
  let application;
  let element;

  beforeEach(() => {
    vi.clearAllMocks();

    document.body.innerHTML = `
      <div data-controller="dropdown" class="dropdown">
        <button data-action="click->dropdown#toggle">Toggle</button>
        <div class="dropdown-menu">
          <a href="/item1">Item 1</a>
          <a href="/item2">Item 2</a>
        </div>
      </div>
    `;

    element = document.querySelector('[data-controller="dropdown"]');
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
    vi.clearAllMocks();
  });

  function startApplication() {
    application = Application.start();
    application.register('dropdown', DropdownController);
  }

  function getController() {
    return application.getControllerForElementAndIdentifier(element, 'dropdown');
  }

  describe('connect', () => {
    describe('when device does not support hover (default)', () => {
      beforeEach(() => {
        startApplication();
      });

      it('does not add is-hoverable class', () => {
        expect(element.classList.contains('is-hoverable')).toBe(false);
      });

      it('sets isHoverable based on supportsHover return value', () => {
        const controller = getController();
        // Default mock returns false
        expect(controller.isHoverable).toBe(false);
      });
    });
  });

  describe('toggle', () => {
    describe('when device does not support hover', () => {
      beforeEach(() => {
        mockSupportsHover.mockReturnValue(false);
        startApplication();
      });

      it('prevents default event behavior', () => {
        const controller = getController();
        const event = {
          preventDefault: vi.fn(),
          stopPropagation: vi.fn()
        };

        controller.toggle(event);

        expect(event.preventDefault).toHaveBeenCalled();
      });

      it('stops event propagation', () => {
        const controller = getController();
        const event = {
          preventDefault: vi.fn(),
          stopPropagation: vi.fn()
        };

        controller.toggle(event);

        expect(event.stopPropagation).toHaveBeenCalled();
      });

      it('adds is-active class when dropdown is closed', () => {
        const controller = getController();
        const event = {
          preventDefault: vi.fn(),
          stopPropagation: vi.fn()
        };

        controller.toggle(event);

        expect(element.classList.contains('is-active')).toBe(true);
      });

      it('removes is-active class when dropdown is open', () => {
        element.classList.add('is-active');
        const controller = getController();
        const event = {
          preventDefault: vi.fn(),
          stopPropagation: vi.fn()
        };

        controller.toggle(event);

        expect(element.classList.contains('is-active')).toBe(false);
      });

      it('dispatches closeDropdowns event when opening', () => {
        const dispatchSpy = vi.spyOn(document, 'dispatchEvent');
        const controller = getController();
        const event = {
          preventDefault: vi.fn(),
          stopPropagation: vi.fn()
        };

        controller.toggle(event);

        expect(dispatchSpy).toHaveBeenCalledWith(expect.any(CustomEvent));
        const customEvent = dispatchSpy.mock.calls[0][0];
        expect(customEvent.type).toBe('closeDropdowns');
      });

      it('does not dispatch closeDropdowns when closing', () => {
        element.classList.add('is-active');
        const dispatchSpy = vi.spyOn(document, 'dispatchEvent');
        const controller = getController();
        const event = {
          preventDefault: vi.fn(),
          stopPropagation: vi.fn()
        };

        controller.toggle(event);

        expect(dispatchSpy).not.toHaveBeenCalled();
      });
    });

    describe('when device supports hover', () => {
      beforeEach(() => {
        mockSupportsHover.mockReturnValue(true);
        startApplication();
      });

      it('does not toggle is-active class', () => {
        const controller = getController();
        const event = {
          preventDefault: vi.fn(),
          stopPropagation: vi.fn()
        };

        controller.toggle(event);

        expect(element.classList.contains('is-active')).toBe(false);
      });
    });
  });

  describe('close', () => {
    describe('when device does not support hover', () => {
      beforeEach(() => {
        mockSupportsHover.mockReturnValue(false);
        startApplication();
      });

      it('removes is-active class', () => {
        element.classList.add('is-active');
        const controller = getController();

        controller.close();

        expect(element.classList.contains('is-active')).toBe(false);
      });

      it('does nothing when already closed', () => {
        const controller = getController();

        controller.close();

        expect(element.classList.contains('is-active')).toBe(false);
      });
    });

    describe('when device supports hover', () => {
      beforeEach(() => {
        mockSupportsHover.mockReturnValue(true);
        startApplication();
      });

      it('does not remove is-active class (handled by CSS)', () => {
        element.classList.add('is-active');
        const controller = getController();

        controller.close();

        // When hoverable, close() doesn't do anything
        expect(element.classList.contains('is-active')).toBe(true);
      });
    });
  });
});
