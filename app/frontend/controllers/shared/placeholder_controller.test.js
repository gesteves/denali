import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';
import PlaceholderController from './placeholder_controller';

describe('PlaceholderController', () => {
  let application;
  let element;
  let rafCallback;

  beforeEach(() => {
    // Mock requestAnimationFrame to capture the callback
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
    vi.useRealTimers();
  });

  describe('connect', () => {
    it('starts checking for image load on connect', () => {
      application = Application.start();
      application.register('placeholder', PlaceholderController);

      // The controller should have started but placeholder is still there
      expect(element.classList.contains('placeholder')).toBe(true);
    });
  });

  describe('removeBackground', () => {
    it('removes placeholder class when image is complete', async () => {
      // Mock the image as loaded
      Object.defineProperty(element, 'complete', { value: true, configurable: true });
      Object.defineProperty(element, 'naturalWidth', { value: 100, configurable: true });
      Object.defineProperty(element, 'naturalHeight', { value: 100, configurable: true });

      application = Application.start();
      application.register('placeholder', PlaceholderController);

      // Wait for the interval to run
      await new Promise(resolve => setTimeout(resolve, 1100));

      // Execute the RAF callback if it was set
      if (rafCallback) rafCallback();

      expect(element.classList.contains('placeholder')).toBe(false);
    });

    it('keeps placeholder class when image is not complete', async () => {
      Object.defineProperty(element, 'complete', { value: false, configurable: true });
      Object.defineProperty(element, 'naturalWidth', { value: 0, configurable: true });
      Object.defineProperty(element, 'naturalHeight', { value: 0, configurable: true });

      application = Application.start();
      application.register('placeholder', PlaceholderController);

      // Wait for interval
      await new Promise(resolve => setTimeout(resolve, 1100));

      expect(element.classList.contains('placeholder')).toBe(true);
    });

    it('keeps placeholder class when image has no natural dimensions', async () => {
      Object.defineProperty(element, 'complete', { value: true, configurable: true });
      Object.defineProperty(element, 'naturalWidth', { value: 0, configurable: true });
      Object.defineProperty(element, 'naturalHeight', { value: 0, configurable: true });

      application = Application.start();
      application.register('placeholder', PlaceholderController);

      await new Promise(resolve => setTimeout(resolve, 1100));

      expect(element.classList.contains('placeholder')).toBe(true);
    });

    it('uses requestAnimationFrame when removing class', async () => {
      Object.defineProperty(element, 'complete', { value: true, configurable: true });
      Object.defineProperty(element, 'naturalWidth', { value: 100, configurable: true });
      Object.defineProperty(element, 'naturalHeight', { value: 100, configurable: true });

      application = Application.start();
      application.register('placeholder', PlaceholderController);

      await new Promise(resolve => setTimeout(resolve, 1100));

      expect(global.requestAnimationFrame).toHaveBeenCalled();
    });
  });
});
