import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';
import RadioTabController from './radio_tab_controller';

describe('RadioTabController', () => {
  let application;
  let element;

  beforeEach(() => {
    document.body.innerHTML = `
      <div data-controller="radio-tab">
        <input type="hidden" data-radio-tab-target="field" value="option1">
        <button data-radio-tab-target="tab" data-radio-tab-value="option1" data-action="click->radio-tab#toggle">Option 1</button>
        <button data-radio-tab-target="tab" data-radio-tab-value="option2" data-action="click->radio-tab#toggle">Option 2</button>
        <button data-radio-tab-target="tab" data-radio-tab-value="option3" data-action="click->radio-tab#toggle">Option 3</button>
      </div>
    `;

    element = document.querySelector('[data-controller="radio-tab"]');
    application = Application.start();
    application.register('radio-tab', RadioTabController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
  });

  function getController() {
    return application.getControllerForElementAndIdentifier(element, 'radio-tab');
  }

  function fieldTarget() {
    return element.querySelector('[data-radio-tab-target="field"]');
  }

  function tabTargets() {
    return element.querySelectorAll('[data-radio-tab-target="tab"]');
  }

  describe('connect', () => {
    it('adds is-active class to tab matching initial field value', () => {
      const tabs = tabTargets();
      expect(tabs[0].classList.contains('is-active')).toBe(true);
      expect(tabs[1].classList.contains('is-active')).toBe(false);
      expect(tabs[2].classList.contains('is-active')).toBe(false);
    });

    it('handles different initial values via toggle', () => {
      // Test that toggling to a different tab works
      const controller = getController();
      const tabs = tabTargets();

      // Click on option2
      controller.toggle({
        preventDefault: vi.fn(),
        currentTarget: tabs[1]
      });

      expect(tabs[0].classList.contains('is-active')).toBe(false);
      expect(tabs[1].classList.contains('is-active')).toBe(true);
      expect(fieldTarget().value).toBe('option2');
    });
  });

  describe('toggle', () => {
    it('prevents default event behavior', () => {
      const controller = getController();
      const tab = tabTargets()[1];
      const event = {
        preventDefault: vi.fn(),
        currentTarget: tab
      };

      controller.toggle(event);

      expect(event.preventDefault).toHaveBeenCalled();
    });

    it('activates clicked tab', () => {
      const controller = getController();
      const tabs = tabTargets();
      const event = {
        preventDefault: vi.fn(),
        currentTarget: tabs[1]
      };

      controller.toggle(event);

      expect(tabs[1].classList.contains('is-active')).toBe(true);
    });

    it('deactivates previously active tab', () => {
      const controller = getController();
      const tabs = tabTargets();
      const event = {
        preventDefault: vi.fn(),
        currentTarget: tabs[1]
      };

      controller.toggle(event);

      expect(tabs[0].classList.contains('is-active')).toBe(false);
    });

    it('updates hidden field value', () => {
      const controller = getController();
      const tabs = tabTargets();
      const event = {
        preventDefault: vi.fn(),
        currentTarget: tabs[1]
      };

      controller.toggle(event);

      expect(fieldTarget().value).toBe('option2');
    });

    it('dispatches change event on field', () => {
      const controller = getController();
      const tabs = tabTargets();
      const changeSpy = vi.fn();
      fieldTarget().addEventListener('change', changeSpy);

      const event = {
        preventDefault: vi.fn(),
        currentTarget: tabs[1]
      };

      controller.toggle(event);

      expect(changeSpy).toHaveBeenCalled();
    });

    it('returns false when clicking already active tab', () => {
      const controller = getController();
      const tabs = tabTargets();
      const event = {
        preventDefault: vi.fn(),
        currentTarget: tabs[0] // Already active
      };

      const result = controller.toggle(event);

      expect(result).toBe(false);
    });

    it('does not change state when clicking already active tab', () => {
      const controller = getController();
      const tabs = tabTargets();
      const changeSpy = vi.fn();
      fieldTarget().addEventListener('change', changeSpy);

      const event = {
        preventDefault: vi.fn(),
        currentTarget: tabs[0] // Already active
      };

      controller.toggle(event);

      expect(changeSpy).not.toHaveBeenCalled();
      expect(fieldTarget().value).toBe('option1');
    });

    it('only has one active tab at a time', () => {
      const controller = getController();
      const tabs = tabTargets();

      // Click each tab in sequence
      [tabs[1], tabs[2], tabs[0]].forEach(tab => {
        controller.toggle({
          preventDefault: vi.fn(),
          currentTarget: tab
        });

        const activeTabs = Array.from(tabs).filter(t => t.classList.contains('is-active'));
        expect(activeTabs.length).toBe(1);
      });
    });
  });
});
