import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';
import PhotoController from './photo_controller';

describe('PhotoController', () => {
  let application;
  let element;

  beforeEach(() => {
    // Mock viewport dimensions
    Object.defineProperty(document.documentElement, 'clientWidth', {
      value: 1200,
      configurable: true
    });
    Object.defineProperty(document.documentElement, 'clientHeight', {
      value: 800,
      configurable: true
    });

    document.body.innerHTML = `
      <div data-controller="photo" data-photo-container-max-width-value="1000">
        <img data-photo-target="photo"
             width="1500"
             height="2000"
             src="/photo1.jpg"
             data-action="click->photo#zoom keydown->photo#zoom contextmenu->photo#disableContextMenu">
        <img data-photo-target="photo"
             width="800"
             height="400"
             src="/photo2.jpg"
             data-action="click->photo#zoom keydown->photo#zoom contextmenu->photo#disableContextMenu">
      </div>
    `;

    element = document.querySelector('[data-controller="photo"]');
    application = Application.start();
    application.register('photo', PhotoController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
    vi.clearAllMocks();
  });

  function getController() {
    return application.getControllerForElementAndIdentifier(element, 'photo');
  }

  function photoTargets() {
    return element.querySelectorAll('[data-photo-target="photo"]');
  }

  describe('connect', () => {
    it('checks zoomability of all photo targets', () => {
      const photos = photoTargets();

      // First photo: 1500x2000, max width is min(1500, 1200, 1000) = 1000
      // At 1000px wide, height would be 1000 * (2000/1500) = 1333px
      // 1333 > 800 (viewport height), so it's zoomable
      expect(photos[0].classList.contains('entry__photo--zoomable')).toBe(true);

      // Second photo: 800x400, max width is min(800, 1200, 1000) = 800
      // At 800px wide, height would be 800 * (400/800) = 400px
      // 400 < 800 (viewport height), so it's NOT zoomable
      expect(photos[1].classList.contains('entry__photo--zoomable')).toBe(false);
    });
  });

  describe('checkIfZoomable', () => {
    it('adds zoomable class when image would be taller than viewport', () => {
      const photos = photoTargets();
      expect(photos[0].classList.contains('entry__photo--zoomable')).toBe(true);
    });

    it('does not add zoomable class when image fits in viewport', () => {
      const photos = photoTargets();
      expect(photos[1].classList.contains('entry__photo--zoomable')).toBe(false);
    });

    it('sets data-photo-zoomable attribute', () => {
      const photos = photoTargets();
      expect(photos[0].getAttribute('data-photo-zoomable')).toBe('1');
      expect(photos[1].getAttribute('data-photo-zoomable')).toBeNull();
    });

    it('sets tabindex for keyboard accessibility', () => {
      const photos = photoTargets();
      expect(photos[0].getAttribute('tabindex')).toBe('0');
      expect(photos[1].getAttribute('tabindex')).toBeNull();
    });

    it('sets role="button" on zoomable photos', () => {
      const photos = photoTargets();
      expect(photos[0].getAttribute('role')).toBe('button');
      expect(photos[1].getAttribute('role')).toBeNull();
    });

    it('sets aria-label on zoomable photos', () => {
      const photos = photoTargets();
      expect(photos[0].getAttribute('aria-label')).toBe('Zoom photo');
      expect(photos[1].getAttribute('aria-label')).toBeNull();
    });

    it('sets aria-expanded="false" on zoomable photos', () => {
      const photos = photoTargets();
      expect(photos[0].getAttribute('aria-expanded')).toBe('false');
      expect(photos[1].getAttribute('aria-expanded')).toBeNull();
    });

    it('respects container max width value', () => {
      // Reset and test with smaller container
      application.stop();

      document.body.innerHTML = `
        <div data-controller="photo" data-photo-container-max-width-value="500">
          <img data-photo-target="photo"
               width="800"
               height="600"
               src="/photo.jpg">
        </div>
      `;

      element = document.querySelector('[data-controller="photo"]');
      application = Application.start();
      application.register('photo', PhotoController);

      const photo = photoTargets()[0];
      // Max width = min(800, 1200, 500) = 500
      // Height at 500px = 500 * (600/800) = 375px
      // 375 < 800 (viewport), so NOT zoomable
      expect(photo.classList.contains('entry__photo--zoomable')).toBe(false);
    });
  });

  describe('zoom', () => {
    it('toggles zoom class on click event', () => {
      const controller = getController();
      const photos = photoTargets();
      const event = {
        type: 'click',
        preventDefault: vi.fn()
      };

      controller.zoom(event);

      expect(photos[0].classList.contains('entry__photo--zoom')).toBe(true);
    });

    it('toggles zoom class on Enter key', () => {
      const controller = getController();
      const photos = photoTargets();
      const event = {
        type: 'keydown',
        key: 'Enter',
        preventDefault: vi.fn()
      };

      controller.zoom(event);

      expect(photos[0].classList.contains('entry__photo--zoom')).toBe(true);
    });

    it('toggles zoom class on Space key', () => {
      const controller = getController();
      const photos = photoTargets();
      const event = {
        type: 'keydown',
        key: ' ',
        preventDefault: vi.fn()
      };

      controller.zoom(event);

      expect(photos[0].classList.contains('entry__photo--zoom')).toBe(true);
    });

    it('does not toggle on other keys', () => {
      const controller = getController();
      const photos = photoTargets();
      const event = {
        type: 'keydown',
        key: 'Tab',
        preventDefault: vi.fn()
      };

      controller.zoom(event);

      expect(photos[0].classList.contains('entry__photo--zoom')).toBe(false);
    });

    it('only toggles zoomable photos', () => {
      const controller = getController();
      const photos = photoTargets();
      const event = {
        type: 'click',
        preventDefault: vi.fn()
      };

      controller.zoom(event);

      // First photo is zoomable
      expect(photos[0].classList.contains('entry__photo--zoom')).toBe(true);
      // Second photo is not zoomable
      expect(photos[1].classList.contains('entry__photo--zoom')).toBe(false);
    });

    it('prevents default behavior', () => {
      const controller = getController();
      const event = {
        type: 'click',
        preventDefault: vi.fn()
      };

      controller.zoom(event);

      expect(event.preventDefault).toHaveBeenCalled();
    });

    it('sets aria-expanded="true" when zoomed in', () => {
      const controller = getController();
      const photos = photoTargets();
      const event = {
        type: 'click',
        preventDefault: vi.fn()
      };

      controller.zoom(event);

      expect(photos[0].getAttribute('aria-expanded')).toBe('true');
    });

    it('sets aria-expanded="false" when zoomed out', () => {
      const controller = getController();
      const photos = photoTargets();
      const event = {
        type: 'click',
        preventDefault: vi.fn()
      };

      controller.zoom(event);
      expect(photos[0].getAttribute('aria-expanded')).toBe('true');

      controller.zoom(event);
      expect(photos[0].getAttribute('aria-expanded')).toBe('false');
    });

    it('toggles zoom off when called again', () => {
      const controller = getController();
      const photos = photoTargets();
      const event = {
        type: 'click',
        preventDefault: vi.fn()
      };

      controller.zoom(event);
      expect(photos[0].classList.contains('entry__photo--zoom')).toBe(true);

      controller.zoom(event);
      expect(photos[0].classList.contains('entry__photo--zoom')).toBe(false);
    });
  });

  describe('disableContextMenu', () => {
    it('prevents default context menu', () => {
      const controller = getController();
      const event = { preventDefault: vi.fn() };

      controller.disableContextMenu(event);

      expect(event.preventDefault).toHaveBeenCalled();
    });
  });
});
