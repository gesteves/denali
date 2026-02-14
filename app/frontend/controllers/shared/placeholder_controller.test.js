import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';
import PlaceholderController from './placeholder_controller';

describe('PlaceholderController', () => {
  let application;
  let element;
  let rafCallback;

  beforeEach(() => {
    rafCallback = null;
    global.requestAnimationFrame = vi.fn(cb => {
      rafCallback = cb;
      return 1;
    });

    document.body.innerHTML = `
      <img data-controller="placeholder"
           class="placeholder"
           src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7">
    `;

    element = document.querySelector('[data-controller="placeholder"]');
  });

  afterEach(() => {
    if (application) {
      application.stop();
    }
    document.body.innerHTML = '';
    vi.clearAllMocks();
  });

  function markImageAsLoaded () {
    Object.defineProperty(element, 'complete', { value: true, configurable: true });
    Object.defineProperty(element, 'naturalWidth', { value: 100, configurable: true });
    Object.defineProperty(element, 'naturalHeight', { value: 100, configurable: true });
  }

  function markImageAsNotLoaded () {
    Object.defineProperty(element, 'complete', { value: false, configurable: true, writable: true });
    Object.defineProperty(element, 'naturalWidth', { value: 0, configurable: true, writable: true });
    Object.defineProperty(element, 'naturalHeight', { value: 0, configurable: true, writable: true });
  }

  function startApplication () {
    application = Application.start();
    application.register('placeholder', PlaceholderController);
  }

  describe('already-loaded image', () => {
    it('removes placeholder class immediately via rAF on connect', async () => {
      markImageAsLoaded();
      startApplication();
      await new Promise(resolve => setTimeout(resolve, 0));

      expect(global.requestAnimationFrame).toHaveBeenCalled();
      expect(element.classList.contains('placeholder')).toBe(true);

      rafCallback();
      expect(element.classList.contains('placeholder')).toBe(false);
    });
  });

  describe('not-yet-loaded image', () => {
    it('removes placeholder class when load event fires', async () => {
      markImageAsNotLoaded();
      startApplication();
      await new Promise(resolve => setTimeout(resolve, 0));

      expect(element.classList.contains('placeholder')).toBe(true);
      expect(global.requestAnimationFrame).not.toHaveBeenCalled();

      markImageAsLoaded();
      element.dispatchEvent(new Event('load'));

      expect(global.requestAnimationFrame).toHaveBeenCalled();
      rafCallback();
      expect(element.classList.contains('placeholder')).toBe(false);
    });
  });

  describe('zero natural dimensions', () => {
    it('keeps placeholder class even if complete is true', async () => {
      Object.defineProperty(element, 'complete', { value: true, configurable: true });
      Object.defineProperty(element, 'naturalWidth', { value: 0, configurable: true });
      Object.defineProperty(element, 'naturalHeight', { value: 0, configurable: true });

      startApplication();
      await new Promise(resolve => setTimeout(resolve, 0));

      expect(element.classList.contains('placeholder')).toBe(true);
      expect(global.requestAnimationFrame).not.toHaveBeenCalled();
    });
  });

  describe('rAF timing', () => {
    it('class is still present before rAF fires, removed after', async () => {
      markImageAsLoaded();
      startApplication();
      await new Promise(resolve => setTimeout(resolve, 0));

      expect(element.classList.contains('placeholder')).toBe(true);
      rafCallback();
      expect(element.classList.contains('placeholder')).toBe(false);
    });
  });

  describe('disconnect', () => {
    it('removes load listener when image is not yet loaded', async () => {
      markImageAsNotLoaded();
      startApplication();
      await new Promise(resolve => setTimeout(resolve, 0));

      const controller = application.getControllerForElementAndIdentifier(element, 'placeholder');
      const removeEventListenerSpy = vi.spyOn(element, 'removeEventListener');

      controller.disconnect();

      expect(removeEventListenerSpy).toHaveBeenCalledWith('load', expect.any(Function));
      expect(controller.onLoad).toBeNull();
    });

    it('is a no-op when image was already loaded', async () => {
      markImageAsLoaded();
      startApplication();
      await new Promise(resolve => setTimeout(resolve, 0));

      const controller = application.getControllerForElementAndIdentifier(element, 'placeholder');
      const removeEventListenerSpy = vi.spyOn(element, 'removeEventListener');

      controller.disconnect();

      expect(removeEventListenerSpy).not.toHaveBeenCalled();
    });

    it('load event after disconnect does not remove placeholder', async () => {
      markImageAsNotLoaded();
      startApplication();
      await new Promise(resolve => setTimeout(resolve, 0));

      const controller = application.getControllerForElementAndIdentifier(element, 'placeholder');
      controller.disconnect();

      markImageAsLoaded();
      element.dispatchEvent(new Event('load'));

      expect(global.requestAnimationFrame).not.toHaveBeenCalled();
      expect(element.classList.contains('placeholder')).toBe(true);
    });
  });
});
