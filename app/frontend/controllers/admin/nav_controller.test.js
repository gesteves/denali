import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';
import NavController from './nav_controller';

describe('NavController', () => {
  let application;
  let element;

  beforeEach(() => {
    document.body.innerHTML = `
      <nav data-controller="nav">
        <button data-nav-target="burger" data-action="click->nav#toggle">Menu</button>
        <div data-nav-target="menu">
          <a href="/page1">Page 1</a>
          <a href="/page2">Page 2</a>
        </div>
      </nav>
    `;

    element = document.querySelector('[data-controller="nav"]');
    application = Application.start();
    application.register('nav', NavController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
  });

  function getController() {
    return application.getControllerForElementAndIdentifier(element, 'nav');
  }

  function burgerTarget() {
    return element.querySelector('[data-nav-target="burger"]');
  }

  function menuTarget() {
    return element.querySelector('[data-nav-target="menu"]');
  }

  describe('toggle', () => {
    it('prevents default event behavior', () => {
      const controller = getController();
      const event = { preventDefault: vi.fn() };

      controller.toggle(event);

      expect(event.preventDefault).toHaveBeenCalled();
    });

    it('adds is-active class to burger when toggled', () => {
      const controller = getController();
      const event = { preventDefault: vi.fn() };

      controller.toggle(event);

      expect(burgerTarget().classList.contains('is-active')).toBe(true);
    });

    it('adds is-active class to menu when toggled', () => {
      const controller = getController();
      const event = { preventDefault: vi.fn() };

      controller.toggle(event);

      expect(menuTarget().classList.contains('is-active')).toBe(true);
    });

    it('removes is-active class when toggled again', () => {
      const controller = getController();
      const event = { preventDefault: vi.fn() };

      controller.toggle(event);
      controller.toggle(event);

      expect(burgerTarget().classList.contains('is-active')).toBe(false);
      expect(menuTarget().classList.contains('is-active')).toBe(false);
    });

    it('toggles both burger and menu in sync', () => {
      const controller = getController();
      const event = { preventDefault: vi.fn() };

      // First toggle - both active
      controller.toggle(event);
      expect(burgerTarget().classList.contains('is-active')).toBe(true);
      expect(menuTarget().classList.contains('is-active')).toBe(true);

      // Second toggle - both inactive
      controller.toggle(event);
      expect(burgerTarget().classList.contains('is-active')).toBe(false);
      expect(menuTarget().classList.contains('is-active')).toBe(false);

      // Third toggle - both active again
      controller.toggle(event);
      expect(burgerTarget().classList.contains('is-active')).toBe(true);
      expect(menuTarget().classList.contains('is-active')).toBe(true);
    });
  });
});
