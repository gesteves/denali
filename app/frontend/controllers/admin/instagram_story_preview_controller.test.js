import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';
import InstagramStoryPreviewController from './instagram_story_preview_controller';

describe('InstagramStoryPreviewController', () => {
  let application;
  let element;

  beforeEach(() => {
    document.body.innerHTML = `
      <div data-controller="instagram-story-preview"
           data-instagram-story-preview-cropped-url-value="https://example.com/cropped.jpg"
           data-instagram-story-preview-uncropped-url-value="https://example.com/uncropped.jpg">
        <img data-instagram-story-preview-target="thumbnail" src="https://example.com/uncropped.jpg">
        <input type="checkbox" data-instagram-story-preview-target="checkbox" data-action="change->instagram-story-preview#updateThumbnail">
      </div>
    `;

    element = document.querySelector('[data-controller="instagram-story-preview"]');
    application = Application.start();
    application.register('instagram-story-preview', InstagramStoryPreviewController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
  });

  function getController() {
    return application.getControllerForElementAndIdentifier(element, 'instagram-story-preview');
  }

  function thumbnailTarget() {
    return element.querySelector('[data-instagram-story-preview-target="thumbnail"]');
  }

  function checkboxTarget() {
    return element.querySelector('[data-instagram-story-preview-target="checkbox"]');
  }

  describe('updateThumbnail', () => {
    describe('with checkbox input', () => {
      it('sets cropped URL when checkbox is checked', () => {
        const controller = getController();
        const event = {
          target: {
            type: 'checkbox',
            checked: true
          }
        };

        controller.updateThumbnail(event);

        expect(thumbnailTarget().src).toBe('https://example.com/cropped.jpg');
      });

      it('sets uncropped URL when checkbox is unchecked', () => {
        const controller = getController();
        // First set to cropped
        thumbnailTarget().src = 'https://example.com/cropped.jpg';

        const event = {
          target: {
            type: 'checkbox',
            checked: false
          }
        };

        controller.updateThumbnail(event);

        expect(thumbnailTarget().src).toBe('https://example.com/uncropped.jpg');
      });
    });

    describe('with hidden input', () => {
      it('sets cropped URL when value is true', () => {
        const controller = getController();
        const event = {
          target: {
            type: 'hidden',
            value: 'true'
          }
        };

        controller.updateThumbnail(event);

        expect(thumbnailTarget().src).toBe('https://example.com/cropped.jpg');
      });

      it('sets uncropped URL when value is false', () => {
        const controller = getController();
        // First set to cropped
        thumbnailTarget().src = 'https://example.com/cropped.jpg';

        const event = {
          target: {
            type: 'hidden',
            value: 'false'
          }
        };

        controller.updateThumbnail(event);

        expect(thumbnailTarget().src).toBe('https://example.com/uncropped.jpg');
      });

      it('sets uncropped URL when value is empty', () => {
        const controller = getController();
        thumbnailTarget().src = 'https://example.com/cropped.jpg';

        const event = {
          target: {
            type: 'hidden',
            value: ''
          }
        };

        controller.updateThumbnail(event);

        expect(thumbnailTarget().src).toBe('https://example.com/uncropped.jpg');
      });
    });

    describe('integration', () => {
      it('toggles thumbnail on checkbox click', () => {
        const checkbox = checkboxTarget();
        const thumbnail = thumbnailTarget();

        // Initial state - uncropped
        expect(thumbnail.src).toBe('https://example.com/uncropped.jpg');

        // Check the checkbox
        checkbox.checked = true;
        checkbox.dispatchEvent(new Event('change'));

        expect(thumbnail.src).toBe('https://example.com/cropped.jpg');

        // Uncheck the checkbox
        checkbox.checked = false;
        checkbox.dispatchEvent(new Event('change'));

        expect(thumbnail.src).toBe('https://example.com/uncropped.jpg');
      });
    });
  });
});
