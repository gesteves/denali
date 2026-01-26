import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';

// Mock utils functions used by focal_point_controller
vi.mock('../../lib/utils', () => ({
  fetchStatus: (response) => response.ok ? Promise.resolve(response) : Promise.reject(),
  fetchJson: (response) => response.json(),
  sendNotification: (message, status) => {
    const event = new CustomEvent('notify', {
      detail: { message, status }
    });
    document.body.dispatchEvent(event);
  }
}));

import FocalPointController from './focal_point_controller';

describe('FocalPointController', () => {
  let application;
  let element;

  beforeEach(() => {
    global.fetch = vi.fn();

    document.body.innerHTML = `
      <div data-controller="focal-point"
           data-focal-point-focal-x-value="0.5"
           data-focal-point-focal-y-value="0.3"
           data-focal-point-endpoint-value="/admin/photos/1/focal_point">
        <div data-focal-point-target="focalMarker" class="focal-marker is-hidden" style="width: 100px; height: 100px;"></div>
        <img data-focal-point-target="thumbnail"
             src="/photo.jpg"
             data-action="click->focal-point#setFocalPoint">
        <input type="hidden" data-focal-point-target="focalX" value="0.5">
        <input type="hidden" data-focal-point-target="focalY" value="0.3">
      </div>
    `;

    element = document.querySelector('[data-controller="focal-point"]');

    // Mock thumbnail dimensions
    const thumbnail = element.querySelector('[data-focal-point-target="thumbnail"]');
    Object.defineProperty(thumbnail, 'offsetWidth', { value: 400, configurable: true });
    Object.defineProperty(thumbnail, 'offsetHeight', { value: 300, configurable: true });

    application = Application.start();
    application.register('focal-point', FocalPointController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
    vi.clearAllMocks();
  });

  function getController() {
    return application.getControllerForElementAndIdentifier(element, 'focal-point');
  }

  function focalMarkerTarget() {
    return element.querySelector('[data-focal-point-target="focalMarker"]');
  }

  function thumbnailTarget() {
    return element.querySelector('[data-focal-point-target="thumbnail"]');
  }

  function focalXTarget() {
    return element.querySelector('[data-focal-point-target="focalX"]');
  }

  function focalYTarget() {
    return element.querySelector('[data-focal-point-target="focalY"]');
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

    it('calls showFocalPoint on connect', () => {
      const marker = focalMarkerTarget();
      expect(marker.classList.contains('is-hidden')).toBe(false);
    });
  });

  describe('showFocalPoint', () => {
    it('positions marker based on focal point values', () => {
      const marker = focalMarkerTarget();

      // With focalX=0.5, focalY=0.3, thumbnail 400x300
      // top = (300 * 0.3) - 50 = 40
      // left = (400 * 0.5) - 50 = 150
      expect(marker.style.top).toBe('40px');
      expect(marker.style.left).toBe('150px');
    });

    it('removes is-hidden class from marker', () => {
      const marker = focalMarkerTarget();
      expect(marker.classList.contains('is-hidden')).toBe(false);
    });

    it('does nothing when focal values are not set', () => {
      application.stop();

      document.body.innerHTML = `
        <div data-controller="focal-point">
          <div data-focal-point-target="focalMarker" class="focal-marker is-hidden"></div>
          <img data-focal-point-target="thumbnail" src="/photo.jpg">
        </div>
      `;

      element = document.querySelector('[data-controller="focal-point"]');
      application = Application.start();
      application.register('focal-point', FocalPointController);

      const marker = focalMarkerTarget();
      expect(marker.classList.contains('is-hidden')).toBe(true);
    });
  });

  describe('setFocalPoint', () => {
    it('prevents default event behavior', () => {
      const controller = getController();
      const thumbnail = thumbnailTarget();

      // Mock getBoundingClientRect
      thumbnail.getBoundingClientRect = vi.fn(() => ({
        top: 100,
        left: 50
      }));

      mockFetchSuccess({ message: 'Saved', status: 'success' });

      const event = {
        preventDefault: vi.fn(),
        pageX: 250, // 50 + 200 = click at 200px from left of thumbnail
        pageY: 200  // 100 + 100 = click at 100px from top of thumbnail
      };

      // Mock scroll position
      Object.defineProperty(window, 'scrollX', { value: 0, configurable: true });
      Object.defineProperty(window, 'scrollY', { value: 0, configurable: true });

      controller.setFocalPoint(event);

      expect(event.preventDefault).toHaveBeenCalled();
    });

    it('calculates focal point from click position', () => {
      const controller = getController();
      const thumbnail = thumbnailTarget();

      thumbnail.getBoundingClientRect = vi.fn(() => ({
        top: 100,
        left: 50
      }));

      mockFetchSuccess({ message: 'Saved', status: 'success' });

      Object.defineProperty(window, 'scrollX', { value: 0, configurable: true });
      Object.defineProperty(window, 'scrollY', { value: 0, configurable: true });

      const event = {
        preventDefault: vi.fn(),
        pageX: 250, // 200px from left edge of 400px thumbnail = 0.5
        pageY: 250  // 150px from top edge of 300px thumbnail = 0.5
      };

      controller.setFocalPoint(event);

      expect(controller.focalXValue).toBe(0.5);
      expect(controller.focalYValue).toBe(0.5);
    });

    it('updates hidden input values', () => {
      const controller = getController();
      const thumbnail = thumbnailTarget();

      thumbnail.getBoundingClientRect = vi.fn(() => ({
        top: 0,
        left: 0
      }));

      mockFetchSuccess({ message: 'Saved', status: 'success' });

      Object.defineProperty(window, 'scrollX', { value: 0, configurable: true });
      Object.defineProperty(window, 'scrollY', { value: 0, configurable: true });

      const event = {
        preventDefault: vi.fn(),
        pageX: 100, // 100/400 = 0.25
        pageY: 75   // 75/300 = 0.25
      };

      controller.setFocalPoint(event);

      expect(focalXTarget().value).toBe('0.25');
      expect(focalYTarget().value).toBe('0.25');
    });

    it('calls updateFocalPoint when endpoint is set', async () => {
      mockFetchSuccess({ message: 'Focal point saved', status: 'success' });

      const controller = getController();
      const thumbnail = thumbnailTarget();

      thumbnail.getBoundingClientRect = vi.fn(() => ({ top: 0, left: 0 }));
      Object.defineProperty(window, 'scrollX', { value: 0, configurable: true });
      Object.defineProperty(window, 'scrollY', { value: 0, configurable: true });

      const event = {
        preventDefault: vi.fn(),
        pageX: 200,
        pageY: 150
      };

      controller.setFocalPoint(event);

      await vi.waitFor(() => {
        expect(global.fetch).toHaveBeenCalled();
      });
    });

    it('repositions marker after setting focal point', () => {
      mockFetchSuccess({ message: 'Saved', status: 'success' });

      const controller = getController();
      const thumbnail = thumbnailTarget();
      const marker = focalMarkerTarget();

      thumbnail.getBoundingClientRect = vi.fn(() => ({ top: 0, left: 0 }));
      Object.defineProperty(window, 'scrollX', { value: 0, configurable: true });
      Object.defineProperty(window, 'scrollY', { value: 0, configurable: true });

      const event = {
        preventDefault: vi.fn(),
        pageX: 200,
        pageY: 150
      };

      controller.setFocalPoint(event);

      // New position: x=0.5, y=0.5
      // top = (300 * 0.5) - 50 = 100
      // left = (400 * 0.5) - 50 = 150
      expect(marker.style.top).toBe('100px');
      expect(marker.style.left).toBe('150px');
    });
  });

  describe('updateFocalPoint', () => {
    it('sends POST request with focal point data', async () => {
      mockFetchSuccess({ message: 'Saved', status: 'success' });

      const controller = getController();

      controller.updateFocalPoint();

      await vi.waitFor(() => {
        expect(global.fetch).toHaveBeenCalledWith(
          '/admin/photos/1/focal_point',
          expect.objectContaining({
            method: 'POST',
            credentials: 'include'
          })
        );
      });
    });

    it('includes CSRF token in headers', async () => {
      mockFetchSuccess({ message: 'Saved', status: 'success' });

      const controller = getController();

      controller.updateFocalPoint();

      await vi.waitFor(() => {
        const headers = global.fetch.mock.calls[0][1].headers;
        expect(headers.get('X-CSRF-Token')).toBe('test-csrf-token');
      });
    });

    it('sends FormData with focal point values', async () => {
      mockFetchSuccess({ message: 'Saved', status: 'success' });

      const controller = getController();

      controller.updateFocalPoint();

      await vi.waitFor(() => {
        const body = global.fetch.mock.calls[0][1].body;
        expect(body instanceof FormData).toBe(true);
        expect(body.get('photo[focal_x]')).toBe('0.5');
        expect(body.get('photo[focal_y]')).toBe('0.3');
      });
    });

    it('sends notification on success', async () => {
      mockFetchSuccess({ message: 'Focal point saved!', status: 'success' });
      const dispatchSpy = vi.spyOn(document.body, 'dispatchEvent');

      const controller = getController();

      controller.updateFocalPoint();

      await vi.waitFor(() => {
        const notifyEvent = dispatchSpy.mock.calls.find(call => call[0].type === 'notify');
        expect(notifyEvent).toBeDefined();
        expect(notifyEvent[0].detail.message).toBe('Focal point saved!');
        expect(notifyEvent[0].detail.status).toBe('success');
      });
    });
  });
});
