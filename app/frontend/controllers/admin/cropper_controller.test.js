import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';
import CropperController from './cropper_controller';

// Mock Croppr library
const mockCropprInstance = {
  getValue: vi.fn(() => ({ x: 0.1, y: 0.1, width: 0.5, height: 0.5 })),
  resizeTo: vi.fn(),
  moveTo: vi.fn()
};

vi.mock('croppr', () => ({
  default: class MockCroppr {
    constructor(element, options) {
      this.element = element;
      this.options = options;
      // Call onInitialize callback if provided
      if (options.onInitialize) {
        // Simulate async initialization
        setTimeout(() => options.onInitialize(mockCropprInstance), 0);
      }
      return mockCropprInstance;
    }
  }
}));

describe('CropperController', () => {
  let application;
  let element;

  beforeEach(() => {
    global.fetch = vi.fn();
    global.requestAnimationFrame = vi.fn(cb => cb());

    document.body.innerHTML = `
      <div data-controller="cropper"
           data-cropper-endpoint-value="/admin/photos/1/crop"
           data-cropper-aspect-ratio-value="16:9"
           data-cropper-crop-x-value="0"
           data-cropper-crop-y-value="0"
           data-cropper-crop-width-value="0"
           data-cropper-crop-height-value="0"
           data-cropper-focal-x-value="0.5"
           data-cropper-focal-y-value="0.5">
        <img data-cropper-target="photo" src="/test.jpg" />
        <div class="croppr-imageClipped" style="display: block;"></div>
      </div>
    `;

    element = document.querySelector('[data-controller="cropper"]');
    application = Application.start();
    application.register('cropper', CropperController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
    vi.clearAllMocks();
  });

  function getController() {
    return application.getControllerForElementAndIdentifier(element, 'cropper');
  }

  function mockFetchSuccess(data) {
    global.fetch.mockResolvedValueOnce({
      ok: true,
      json: () => Promise.resolve(data)
    });
  }

  describe('connect', () => {
    it('retrieves CSRF token from meta tag', () => {
      const controller = getController();
      expect(controller.csrfToken).toBe('test-csrf-token');
    });

    it('initializes with initializedCropper as false', () => {
      const controller = getController();
      expect(controller.initializedCropper).toBe(false);
    });
  });

  describe('calculateAspectRatio', () => {
    it('parses "16:9" format correctly', () => {
      const controller = getController();
      const result = controller.calculateAspectRatio('16:9');
      expect(result).toBeCloseTo(9 / 16);
    });

    it('parses "4:3" format correctly', () => {
      const controller = getController();
      const result = controller.calculateAspectRatio('4:3');
      expect(result).toBeCloseTo(3 / 4);
    });

    it('parses "1:1" format correctly', () => {
      const controller = getController();
      const result = controller.calculateAspectRatio('1:1');
      expect(result).toBe(1);
    });

    it('parses float string directly', () => {
      const controller = getController();
      const result = controller.calculateAspectRatio('0.5625');
      expect(result).toBe(0.5625);
    });

    it('handles decimal aspect ratios', () => {
      const controller = getController();
      const result = controller.calculateAspectRatio('1.5');
      expect(result).toBe(1.5);
    });
  });

  describe('updateCrop', () => {
    it('does nothing if cropper not initialized', () => {
      const controller = getController();
      controller.initializedCropper = false;

      controller.updateCrop({ x: 0.1, y: 0.2, width: 0.5, height: 0.3 });

      expect(global.fetch).not.toHaveBeenCalled();
    });

    it('sends POST request with crop data when initialized', async () => {
      mockFetchSuccess({ message: 'Crop saved', status: 'success' });

      const controller = getController();
      controller.initializedCropper = true;

      controller.updateCrop({ x: 0.1, y: 0.2, width: 0.5, height: 0.3 });

      await vi.waitFor(() => {
        expect(global.fetch).toHaveBeenCalledWith(
          '/admin/photos/1/crop',
          expect.objectContaining({
            method: 'POST',
            credentials: 'include'
          })
        );
      });
    });

    it('includes CSRF token in headers', async () => {
      mockFetchSuccess({ message: 'Crop saved', status: 'success' });

      const controller = getController();
      controller.initializedCropper = true;

      controller.updateCrop({ x: 0.1, y: 0.2, width: 0.5, height: 0.3 });

      await vi.waitFor(() => {
        const headers = global.fetch.mock.calls[0][1].headers;
        expect(headers.get('X-CSRF-Token')).toBe('test-csrf-token');
      });
    });

    it('sends FormData with crop values', async () => {
      mockFetchSuccess({ message: 'Crop saved', status: 'success' });

      const controller = getController();
      controller.initializedCropper = true;

      controller.updateCrop({ x: 0.1, y: 0.2, width: 0.5, height: 0.3 });

      await vi.waitFor(() => {
        const body = global.fetch.mock.calls[0][1].body;
        expect(body instanceof FormData).toBe(true);
        expect(body.get('crop[x]')).toBe('0.1');
        expect(body.get('crop[y]')).toBe('0.2');
        expect(body.get('crop[width]')).toBe('0.5');
        expect(body.get('crop[height]')).toBe('0.3');
        expect(body.get('crop[aspect_ratio]')).toBe('16:9');
      });
    });

    it('handles NaN values by converting to 0', async () => {
      mockFetchSuccess({ message: 'Crop saved', status: 'success' });

      const controller = getController();
      controller.initializedCropper = true;

      controller.updateCrop({ x: NaN, y: NaN, width: NaN, height: NaN });

      await vi.waitFor(() => {
        const body = global.fetch.mock.calls[0][1].body;
        expect(body.get('crop[x]')).toBe('0');
        expect(body.get('crop[y]')).toBe('0');
        expect(body.get('crop[width]')).toBe('0');
        expect(body.get('crop[height]')).toBe('0');
      });
    });

    it('updates crop value properties', async () => {
      mockFetchSuccess({ message: 'Crop saved', status: 'success' });

      const controller = getController();
      controller.initializedCropper = true;

      controller.updateCrop({ x: 0.1, y: 0.2, width: 0.5, height: 0.3 });

      expect(controller.cropXValue).toBe(0.1);
      expect(controller.cropYValue).toBe(0.2);
      expect(controller.cropWidthValue).toBe(0.5);
      expect(controller.cropHeightValue).toBe(0.3);
    });

    it('sends notification on success', async () => {
      mockFetchSuccess({ message: 'Crop saved successfully', status: 'success' });
      const dispatchSpy = vi.spyOn(document.body, 'dispatchEvent');

      const controller = getController();
      controller.initializedCropper = true;

      controller.updateCrop({ x: 0.1, y: 0.2, width: 0.5, height: 0.3 });

      await vi.waitFor(() => {
        const notifyEvent = dispatchSpy.mock.calls.find(call => call[0].type === 'notify');
        expect(notifyEvent).toBeDefined();
        expect(notifyEvent[0].detail.message).toBe('Crop saved successfully');
      });
    });
  });

  describe('fixCropperOverlay', () => {
    it('toggles display to fix rendering glitch', () => {
      const controller = getController();
      const clippedImage = element.querySelector('.croppr-imageClipped');

      controller.fixCropperOverlay();

      // requestAnimationFrame callback should set display back to block
      expect(clippedImage.style.display).toBe('block');
    });
  });

  describe('setInitialCropperPosition', () => {
    it('uses existing crop data when available', () => {
      const controller = getController();
      controller.cropWidthValue = 0.6;
      controller.cropHeightValue = 0.4;
      controller.cropXValue = 0.1;
      controller.cropYValue = 0.2;

      // Mock element dimensions
      Object.defineProperty(element, 'offsetWidth', { value: 1000 });
      Object.defineProperty(element, 'offsetHeight', { value: 600 });

      controller.setInitialCropperPosition(mockCropprInstance);

      expect(mockCropprInstance.resizeTo).toHaveBeenCalledWith(600, 240);
      expect(mockCropprInstance.moveTo).toHaveBeenCalledWith(100, 120);
      expect(controller.initializedCropper).toBe(true);
    });

    it('uses focal point when no crop data exists', () => {
      const controller = getController();
      controller.cropWidthValue = 0;
      controller.cropHeightValue = 0;
      controller.focalXValue = 0.5;
      controller.focalYValue = 0.5;

      // Mock element dimensions
      Object.defineProperty(element, 'offsetWidth', { value: 1000 });
      Object.defineProperty(element, 'offsetHeight', { value: 600 });

      mockCropprInstance.getValue.mockReturnValue({ width: 0.5, height: 0.5 });

      controller.setInitialCropperPosition(mockCropprInstance);

      expect(mockCropprInstance.moveTo).toHaveBeenCalled();
      expect(controller.initializedCropper).toBe(true);
    });

    it('sets initializedCropper to true after positioning', () => {
      const controller = getController();
      controller.cropWidthValue = 0;
      controller.cropHeightValue = 0;
      controller.focalXValue = 0;
      controller.focalYValue = 0;

      controller.setInitialCropperPosition(mockCropprInstance);

      expect(controller.initializedCropper).toBe(true);
    });

    it('constrains position to element bounds', () => {
      const controller = getController();
      controller.cropWidthValue = 0;
      controller.cropHeightValue = 0;
      controller.focalXValue = 0.9; // Near right edge
      controller.focalYValue = 0.9; // Near bottom edge

      // Mock element dimensions
      Object.defineProperty(element, 'offsetWidth', { value: 1000 });
      Object.defineProperty(element, 'offsetHeight', { value: 600 });

      mockCropprInstance.getValue.mockReturnValue({ width: 0.5, height: 0.5 });

      controller.setInitialCropperPosition(mockCropprInstance);

      // The x and y should be constrained so cropper doesn't go outside bounds
      const moveToCall = mockCropprInstance.moveTo.mock.calls[0];
      expect(moveToCall[0]).toBeLessThanOrEqual(500); // 1000 - (1000 * 0.5)
      expect(moveToCall[1]).toBeLessThanOrEqual(300); // 600 - (600 * 0.5)
    });
  });
});
