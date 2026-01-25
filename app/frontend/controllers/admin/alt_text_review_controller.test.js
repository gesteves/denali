import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';
import AltTextReviewController from './alt_text_review_controller';

describe('AltTextReviewController', () => {
  let application;
  let element;

  beforeEach(() => {
    global.fetch = vi.fn();

    document.body.innerHTML = `
      <div data-controller="alt-text-review"
           data-alt-text-review-generate-url-value="/photos/1/generate_alt_text"
           data-alt-text-review-approve-url-value="/photos/1/approve_alt_text"
           data-alt-text-review-dismiss-url-value="/photos/1/dismiss_alt_text">
        <div>
          <p data-alt-text-review-target="currentAltText">Current alt text here</p>
        </div>
        <div class="is-hidden" data-alt-text-review-target="generatedField">
          <textarea data-alt-text-review-target="generatedAltText"></textarea>
        </div>
        <div class="is-hidden" data-alt-text-review-target="editField">
          <textarea data-alt-text-review-target="editAltText"></textarea>
        </div>
        <div data-alt-text-review-target="generateButtonContainer">
          <button data-alt-text-review-target="generateButton" data-action="click->alt-text-review#generate">Generate</button>
        </div>
        <div data-alt-text-review-target="editButtonContainer">
          <button data-alt-text-review-target="editButton" data-action="click->alt-text-review#edit">Edit</button>
        </div>
        <div class="is-hidden" data-alt-text-review-target="saveButtonContainer">
          <button data-alt-text-review-target="saveButton" data-action="click->alt-text-review#save">Save</button>
        </div>
        <div class="is-hidden" data-alt-text-review-target="dismissButtonContainer">
          <button data-alt-text-review-target="dismissButton" data-action="click->alt-text-review#dismiss">Dismiss</button>
        </div>
      </div>
    `;

    element = document.querySelector('[data-controller="alt-text-review"]');
    application = Application.start();
    application.register('alt-text-review', AltTextReviewController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
    vi.clearAllMocks();
  });

  function getController() {
    return application.getControllerForElementAndIdentifier(element, 'alt-text-review');
  }

  function generateButton() {
    return element.querySelector('[data-alt-text-review-target="generateButton"]');
  }

  function saveButton() {
    return element.querySelector('[data-alt-text-review-target="saveButton"]');
  }

  function dismissButton() {
    return element.querySelector('[data-alt-text-review-target="dismissButton"]');
  }

  function editButton() {
    return element.querySelector('[data-alt-text-review-target="editButton"]');
  }

  function generatedField() {
    return element.querySelector('[data-alt-text-review-target="generatedField"]');
  }

  function editField() {
    return element.querySelector('[data-alt-text-review-target="editField"]');
  }

  function generatedAltText() {
    return element.querySelector('[data-alt-text-review-target="generatedAltText"]');
  }

  function editAltText() {
    return element.querySelector('[data-alt-text-review-target="editAltText"]');
  }

  function currentAltText() {
    return element.querySelector('[data-alt-text-review-target="currentAltText"]');
  }

  function saveButtonContainer() {
    return element.querySelector('[data-alt-text-review-target="saveButtonContainer"]');
  }

  function dismissButtonContainer() {
    return element.querySelector('[data-alt-text-review-target="dismissButtonContainer"]');
  }

  function generateButtonContainer() {
    return element.querySelector('[data-alt-text-review-target="generateButtonContainer"]');
  }

  function editButtonContainer() {
    return element.querySelector('[data-alt-text-review-target="editButtonContainer"]');
  }

  function mockFetchSuccess(data) {
    global.fetch.mockResolvedValueOnce({
      ok: true,
      json: () => Promise.resolve(data)
    });
  }

  function mockFetchError() {
    global.fetch.mockResolvedValueOnce({
      ok: false,
      status: 500
    });
  }

  describe('connect', () => {
    it('retrieves CSRF token from meta tag', () => {
      const controller = getController();
      expect(controller.csrfToken).toBe('test-csrf-token');
    });
  });

  describe('generate', () => {
    it('shows loading state on button', async () => {
      let resolvePromise;
      global.fetch.mockReturnValue(new Promise(resolve => {
        resolvePromise = resolve;
      }));

      generateButton().click();

      expect(generateButton().classList.contains('is-loading')).toBe(true);
      expect(generateButton().disabled).toBe(true);

      resolvePromise({ ok: true, json: () => Promise.resolve({ auto_generated_alt_text: 'test' }) });
    });

    it('makes POST request to generate URL', async () => {
      mockFetchSuccess({ auto_generated_alt_text: 'A sunset over mountains' });

      generateButton().click();

      await vi.waitFor(() => {
        expect(global.fetch).toHaveBeenCalledWith(
          '/photos/1/generate_alt_text',
          expect.objectContaining({
            method: 'POST',
            credentials: 'include'
          })
        );
      });
    });

    it('includes CSRF token in headers', async () => {
      mockFetchSuccess({ auto_generated_alt_text: 'A sunset' });

      generateButton().click();

      await vi.waitFor(() => {
        const headers = global.fetch.mock.calls[0][1].headers;
        expect(headers.get('X-CSRF-Token')).toBe('test-csrf-token');
      });
    });

    it('populates generated alt text field on success', async () => {
      mockFetchSuccess({ auto_generated_alt_text: 'A beautiful sunset over mountains' });

      generateButton().click();

      await vi.waitFor(() => {
        expect(generatedAltText().value).toBe('A beautiful sunset over mountains');
      });
    });

    it('shows generated field, save and dismiss buttons on success', async () => {
      mockFetchSuccess({ auto_generated_alt_text: 'Generated text' });

      generateButton().click();

      await vi.waitFor(() => {
        expect(generatedField().classList.contains('is-hidden')).toBe(false);
        expect(saveButtonContainer().classList.contains('is-hidden')).toBe(false);
        expect(dismissButtonContainer().classList.contains('is-hidden')).toBe(false);
      });
    });

    it('hides edit button on success', async () => {
      mockFetchSuccess({ auto_generated_alt_text: 'Generated text' });

      generateButton().click();

      await vi.waitFor(() => {
        expect(editButtonContainer().classList.contains('is-hidden')).toBe(true);
      });
    });

    it('removes loading state on success', async () => {
      mockFetchSuccess({ auto_generated_alt_text: 'Generated text' });

      generateButton().click();

      await vi.waitFor(() => {
        expect(generateButton().classList.contains('is-loading')).toBe(false);
        expect(generateButton().disabled).toBe(false);
      });
    });

    it('sends notification on error', async () => {
      mockFetchError();
      const dispatchSpy = vi.spyOn(document.body, 'dispatchEvent');

      generateButton().click();

      await vi.waitFor(() => {
        expect(dispatchSpy).toHaveBeenCalled();
        const event = dispatchSpy.mock.calls[0][0];
        expect(event.detail.message).toBe('Failed to generate alt text.');
        expect(event.detail.status).toBe('danger');
      });
    });

    it('removes loading state on error', async () => {
      mockFetchError();

      generateButton().click();

      await vi.waitFor(() => {
        expect(generateButton().classList.contains('is-loading')).toBe(false);
        expect(generateButton().disabled).toBe(false);
      });
    });
  });

  describe('edit', () => {
    it('copies current alt text to edit textarea', () => {
      editButton().click();

      expect(editAltText().value).toBe('Current alt text here');
    });

    it('shows edit field and hides current alt text', () => {
      editButton().click();

      expect(editField().classList.contains('is-hidden')).toBe(false);
      expect(currentAltText().parentElement.classList.contains('is-hidden')).toBe(true);
    });

    it('hides generate and edit buttons', () => {
      editButton().click();

      expect(generateButtonContainer().classList.contains('is-hidden')).toBe(true);
      expect(editButtonContainer().classList.contains('is-hidden')).toBe(true);
    });

    it('shows dismiss and save buttons', () => {
      editButton().click();

      expect(dismissButtonContainer().classList.contains('is-hidden')).toBe(false);
      expect(saveButtonContainer().classList.contains('is-hidden')).toBe(false);
    });
  });

  describe('isInEditMode', () => {
    it('returns false initially', () => {
      const controller = getController();
      expect(controller.isInEditMode()).toBe(false);
    });

    it('returns true after clicking edit', () => {
      const controller = getController();
      editButton().click();
      expect(controller.isInEditMode()).toBe(true);
    });
  });

  describe('save', () => {
    it('shows loading state on save button', async () => {
      mockFetchSuccess({ auto_generated_alt_text: 'Generated' });
      generateButton().click();
      await vi.waitFor(() => expect(generatedField().classList.contains('is-hidden')).toBe(false));

      let resolvePromise;
      global.fetch.mockReturnValue(new Promise(resolve => {
        resolvePromise = resolve;
      }));

      saveButton().click();

      expect(saveButton().classList.contains('is-loading')).toBe(true);
      expect(saveButton().disabled).toBe(true);

      resolvePromise({ ok: true, json: () => Promise.resolve({ alt_text: 'Saved' }) });
    });

    it('sends generated alt text when not in edit mode', async () => {
      mockFetchSuccess({ auto_generated_alt_text: 'AI generated text' });
      generateButton().click();
      await vi.waitFor(() => expect(generatedAltText().value).toBe('AI generated text'));

      mockFetchSuccess({ alt_text: 'AI generated text' });
      saveButton().click();

      await vi.waitFor(() => {
        const body = JSON.parse(global.fetch.mock.calls[1][1].body);
        expect(body.text).toBe('AI generated text');
      });
    });

    it('sends edited alt text when in edit mode', async () => {
      editButton().click();
      editAltText().value = 'My custom alt text';

      mockFetchSuccess({ alt_text: 'My custom alt text' });
      saveButton().click();

      await vi.waitFor(() => {
        const body = JSON.parse(global.fetch.mock.calls[0][1].body);
        expect(body.text).toBe('My custom alt text');
      });
    });

    it('updates current alt text display on success', async () => {
      mockFetchSuccess({ auto_generated_alt_text: 'Generated' });
      generateButton().click();
      await vi.waitFor(() => expect(generatedField().classList.contains('is-hidden')).toBe(false));

      mockFetchSuccess({ alt_text: 'New saved alt text' });
      saveButton().click();

      await vi.waitFor(() => {
        expect(currentAltText().textContent).toBe('New saved alt text');
      });
    });

    it('hides generated and edit fields, shows current alt text on success', async () => {
      mockFetchSuccess({ auto_generated_alt_text: 'Generated' });
      generateButton().click();
      await vi.waitFor(() => expect(generatedField().classList.contains('is-hidden')).toBe(false));

      mockFetchSuccess({ alt_text: 'Saved' });
      saveButton().click();

      await vi.waitFor(() => {
        expect(generatedField().classList.contains('is-hidden')).toBe(true);
        expect(editField().classList.contains('is-hidden')).toBe(true);
        expect(currentAltText().parentElement.classList.contains('is-hidden')).toBe(false);
      });
    });

    it('shows generate and edit buttons on success', async () => {
      mockFetchSuccess({ auto_generated_alt_text: 'Generated' });
      generateButton().click();
      await vi.waitFor(() => expect(generatedField().classList.contains('is-hidden')).toBe(false));

      mockFetchSuccess({ alt_text: 'Saved' });
      saveButton().click();

      await vi.waitFor(() => {
        expect(generateButtonContainer().classList.contains('is-hidden')).toBe(false);
        expect(editButtonContainer().classList.contains('is-hidden')).toBe(false);
      });
    });

    it('sends notification on error', async () => {
      editButton().click();
      mockFetchError();
      const dispatchSpy = vi.spyOn(document.body, 'dispatchEvent');

      saveButton().click();

      await vi.waitFor(() => {
        const notifyEvent = dispatchSpy.mock.calls.find(call => call[0].type === 'notify');
        expect(notifyEvent).toBeDefined();
        expect(notifyEvent[0].detail.message).toBe('Failed to save alt text.');
      });
    });
  });

  describe('dismiss', () => {
    it('shows loading state on dismiss button', async () => {
      mockFetchSuccess({ auto_generated_alt_text: 'Generated' });
      generateButton().click();
      await vi.waitFor(() => expect(generatedField().classList.contains('is-hidden')).toBe(false));

      let resolvePromise;
      global.fetch.mockReturnValue(new Promise(resolve => {
        resolvePromise = resolve;
      }));

      dismissButton().click();

      expect(dismissButton().classList.contains('is-loading')).toBe(true);
      expect(dismissButton().disabled).toBe(true);

      resolvePromise({ ok: true, json: () => Promise.resolve({}) });
    });

    it('makes POST request to dismiss URL', async () => {
      mockFetchSuccess({ auto_generated_alt_text: 'Generated' });
      generateButton().click();
      await vi.waitFor(() => expect(generatedField().classList.contains('is-hidden')).toBe(false));

      mockFetchSuccess({});
      dismissButton().click();

      await vi.waitFor(() => {
        expect(global.fetch).toHaveBeenCalledWith(
          '/photos/1/dismiss_alt_text',
          expect.objectContaining({
            method: 'POST'
          })
        );
      });
    });

    it('hides generated and edit fields on success', async () => {
      mockFetchSuccess({ auto_generated_alt_text: 'Generated' });
      generateButton().click();
      await vi.waitFor(() => expect(generatedField().classList.contains('is-hidden')).toBe(false));

      mockFetchSuccess({});
      dismissButton().click();

      await vi.waitFor(() => {
        expect(generatedField().classList.contains('is-hidden')).toBe(true);
        expect(editField().classList.contains('is-hidden')).toBe(true);
      });
    });

    it('shows current alt text display on success', async () => {
      mockFetchSuccess({ auto_generated_alt_text: 'Generated' });
      generateButton().click();
      await vi.waitFor(() => expect(generatedField().classList.contains('is-hidden')).toBe(false));

      mockFetchSuccess({});
      dismissButton().click();

      await vi.waitFor(() => {
        expect(currentAltText().parentElement.classList.contains('is-hidden')).toBe(false);
      });
    });

    it('shows generate and edit buttons on success', async () => {
      mockFetchSuccess({ auto_generated_alt_text: 'Generated' });
      generateButton().click();
      await vi.waitFor(() => expect(generatedField().classList.contains('is-hidden')).toBe(false));

      mockFetchSuccess({});
      dismissButton().click();

      await vi.waitFor(() => {
        expect(generateButtonContainer().classList.contains('is-hidden')).toBe(false);
        expect(editButtonContainer().classList.contains('is-hidden')).toBe(false);
      });
    });

    it('sends notification on error', async () => {
      mockFetchSuccess({ auto_generated_alt_text: 'Generated' });
      generateButton().click();
      await vi.waitFor(() => expect(generatedField().classList.contains('is-hidden')).toBe(false));

      mockFetchError();
      const dispatchSpy = vi.spyOn(document.body, 'dispatchEvent');

      dismissButton().click();

      await vi.waitFor(() => {
        const notifyEvent = dispatchSpy.mock.calls.find(call => call[0].type === 'notify');
        expect(notifyEvent).toBeDefined();
        expect(notifyEvent[0].detail.message).toBe('Failed to dismiss alt text.');
      });
    });

    it('removes loading state on error', async () => {
      mockFetchSuccess({ auto_generated_alt_text: 'Generated' });
      generateButton().click();
      await vi.waitFor(() => expect(generatedField().classList.contains('is-hidden')).toBe(false));

      mockFetchError();
      dismissButton().click();

      await vi.waitFor(() => {
        expect(dismissButton().classList.contains('is-loading')).toBe(false);
        expect(dismissButton().disabled).toBe(false);
      });
    });
  });
});
