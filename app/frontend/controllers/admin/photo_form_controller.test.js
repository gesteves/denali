import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';
import PhotoFormController from './photo_form_controller';

describe('PhotoFormController', () => {
  let application;
  let element;

  beforeEach(() => {
    window.confirm = vi.fn(() => true);

    document.body.innerHTML = `
      <div id="wrapper">
        <div data-controller="photo-form" data-photo-form-empty-value="false">
          <img data-photo-form-target="thumbnail" src="/placeholder.jpg">
          <input type="hidden" data-photo-form-target="position" value="1">
          <input type="hidden" data-photo-form-target="destroy" value="false">
          <div data-photo-form-target="fields" class="is-hidden">Caption fields</div>
          <div data-photo-form-target="fields">More fields</div>
          <button data-action="click->photo-form#delete">Delete</button>
          <input type="file" data-action="change->photo-form#addFromFile" accept="image/jpeg">
        </div>
      </div>
    `;

    element = document.querySelector('[data-controller="photo-form"]');
    application = Application.start();
    application.register('photo-form', PhotoFormController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
    vi.clearAllMocks();
  });

  function getController() {
    return application.getControllerForElementAndIdentifier(element, 'photo-form');
  }

  function thumbnailTarget() {
    return element.querySelector('[data-photo-form-target="thumbnail"]');
  }

  function destroyTarget() {
    return element.querySelector('[data-photo-form-target="destroy"]');
  }

  function fieldsTargets() {
    return element.querySelectorAll('[data-photo-form-target="fields"]');
  }

  describe('delete', () => {
    describe('when form is not empty', () => {
      it('prevents default event behavior', () => {
        const controller = getController();
        const event = { preventDefault: vi.fn() };

        controller.delete(event);

        expect(event.preventDefault).toHaveBeenCalled();
      });

      it('shows confirmation dialog', () => {
        const controller = getController();
        const event = { preventDefault: vi.fn() };

        controller.delete(event);

        expect(window.confirm).toHaveBeenCalled();
        expect(window.confirm.mock.calls[0][0]).toContain('remove this photo');
      });

      it('sets destroy field to true when confirmed', () => {
        window.confirm = vi.fn(() => true);
        const controller = getController();
        const event = { preventDefault: vi.fn() };

        controller.delete(event);

        expect(destroyTarget().value).toBe('true');
      });

      it('hides element when confirmed', () => {
        window.confirm = vi.fn(() => true);
        const controller = getController();
        const event = { preventDefault: vi.fn() };

        controller.delete(event);

        expect(element.style.display).toBe('none');
      });

      it('does nothing when confirmation is cancelled', () => {
        window.confirm = vi.fn(() => false);
        const controller = getController();
        const event = { preventDefault: vi.fn() };

        controller.delete(event);

        expect(destroyTarget().value).toBe('false');
        expect(element.style.display).not.toBe('none');
      });
    });

    describe('when form is empty', () => {
      beforeEach(() => {
        element.setAttribute('data-photo-form-empty-value', 'true');
        // Reinitialize controller
        application.stop();
        application = Application.start();
        application.register('photo-form', PhotoFormController);
      });

      it('does not show confirmation dialog', () => {
        const controller = getController();
        const event = { preventDefault: vi.fn() };

        controller.delete(event);

        expect(window.confirm).not.toHaveBeenCalled();
      });

      it('hides element immediately', () => {
        const controller = getController();
        const event = { preventDefault: vi.fn() };

        controller.delete(event);

        expect(element.style.display).toBe('none');
      });
    });

    describe('when no destroy target exists', () => {
      beforeEach(() => {
        // Remove destroy target
        destroyTarget().remove();
        // Set as empty so no confirm
        element.setAttribute('data-photo-form-empty-value', 'true');
        // Reinitialize controller
        application.stop();
        application = Application.start();
        application.register('photo-form', PhotoFormController);
      });

      it('removes element from DOM', () => {
        const controller = getController();
        const event = { preventDefault: vi.fn() };

        controller.delete(event);

        expect(document.querySelector('[data-controller="photo-form"]')).toBeNull();
      });
    });
  });

  describe('setThumbnail', () => {
    it('sets thumbnail src to provided URL', () => {
      const controller = getController();

      controller.setThumbnail('https://example.com/photo.jpg');

      expect(thumbnailTarget().src).toBe('https://example.com/photo.jpg');
    });

    it('toggles fields visibility', () => {
      const controller = getController();
      const fields = fieldsTargets();

      // Initial state: first field is hidden, second is visible
      expect(fields[0].classList.contains('is-hidden')).toBe(true);
      expect(fields[1].classList.contains('is-hidden')).toBe(false);

      controller.setThumbnail('https://example.com/photo.jpg');

      // After toggle: first field is visible, second is hidden
      expect(fields[0].classList.contains('is-hidden')).toBe(false);
      expect(fields[1].classList.contains('is-hidden')).toBe(true);
    });

    it('sets emptyValue to false', () => {
      const controller = getController();
      controller.emptyValue = true;

      controller.setThumbnail('https://example.com/photo.jpg');

      expect(controller.emptyValue).toBe(false);
    });
  });

  describe('addFromFile', () => {
    it('does nothing for non-JPEG files', () => {
      const controller = getController();
      const setThumbnailSpy = vi.spyOn(controller, 'setThumbnail');

      const event = {
        target: {
          files: [{ type: 'image/png' }]
        }
      };

      controller.addFromFile(event);

      expect(setThumbnailSpy).not.toHaveBeenCalled();
    });

    it('reads JPEG file and sets thumbnail', async () => {
      const controller = getController();
      const setThumbnailSpy = vi.spyOn(controller, 'setThumbnail');

      // Mock FileReader as a class
      let loadCallback;
      class MockFileReader {
        addEventListener(event, callback) {
          if (event === 'load') {
            loadCallback = callback;
          }
        }
        readAsDataURL(file) {
          // Simulate async file read
          setTimeout(() => loadCallback({ target: { result: 'data:image/jpeg;base64,abc123' } }), 0);
        }
      }
      global.FileReader = MockFileReader;

      const event = {
        target: {
          files: [{ type: 'image/jpeg' }]
        }
      };

      controller.addFromFile(event);

      // Wait for async callback
      await vi.waitFor(() => {
        expect(setThumbnailSpy).toHaveBeenCalledWith('data:image/jpeg;base64,abc123');
      });
    });

    it('accepts jpg files', async () => {
      const controller = getController();
      const setThumbnailSpy = vi.spyOn(controller, 'setThumbnail');

      let loadCallback;
      class MockFileReader {
        addEventListener(event, callback) {
          if (event === 'load') {
            loadCallback = callback;
          }
        }
        readAsDataURL(file) {
          setTimeout(() => loadCallback({ target: { result: 'data:image/jpg;base64,abc' } }), 0);
        }
      }
      global.FileReader = MockFileReader;

      const event = {
        target: {
          files: [{ type: 'image/jpg' }]
        }
      };

      controller.addFromFile(event);

      await vi.waitFor(() => {
        expect(setThumbnailSpy).toHaveBeenCalledWith('data:image/jpg;base64,abc');
      });
    });
  });

  describe('stopPropagation', () => {
    it('stops event propagation', () => {
      const controller = getController();
      const event = { stopPropagation: vi.fn() };

      controller.stopPropagation(event);

      expect(event.stopPropagation).toHaveBeenCalled();
    });
  });
});
