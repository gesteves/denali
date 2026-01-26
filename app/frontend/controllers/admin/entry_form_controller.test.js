import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';
import EntryFormController from './entry_form_controller';

// Mock @shopify/draggable
vi.mock('@shopify/draggable', () => ({
  Sortable: class MockSortable {
    constructor(container, options) {
      this.container = container;
      this.options = options;
      this.handlers = {};
    }
    on(event, handler) {
      this.handlers[event] = handler;
    }
    trigger(event, data) {
      if (this.handlers[event]) {
        this.handlers[event](data);
      }
    }
    destroy() {}
  },
  Plugins: {
    SwapAnimation: 'SwapAnimation'
  }
}));

describe('EntryFormController', () => {
  let application;
  let element;

  beforeEach(() => {
    global.fetch = vi.fn();

    document.body.innerHTML = `
      <form data-controller="entry-form"
            data-entry-form-photo-endpoint-value="/admin/entries/new/photo"
            data-action="submit->entry-form#submit">
        <div data-entry-form-target="photos">
          <div class="photo-field">
            <input type="hidden" data-position value="1">
            <div class="draggable-handle">Photo 1</div>
          </div>
          <div class="photo-field">
            <input type="hidden" data-position value="2">
            <div class="draggable-handle">Photo 2</div>
          </div>
        </div>
        <button type="button" data-action="click->entry-form#addPhoto">Add Photo</button>
        <button type="submit">Save</button>
      </form>
    `;

    element = document.querySelector('[data-controller="entry-form"]');
    application = Application.start();
    application.register('entry-form', EntryFormController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
    vi.clearAllMocks();
  });

  function getController() {
    return application.getControllerForElementAndIdentifier(element, 'entry-form');
  }

  function photosTarget() {
    return element.querySelector('[data-entry-form-target="photos"]');
  }

  function positionInputs() {
    return element.querySelectorAll('input[data-position]');
  }

  function mockFetchSuccess(html) {
    global.fetch.mockResolvedValueOnce({
      ok: true,
      text: () => Promise.resolve(html)
    });
  }

  describe('connect', () => {
    it('retrieves CSRF token from meta tag', () => {
      const controller = getController();
      expect(controller.csrfToken).toBe('test-csrf-token');
    });

    it('initializes sortable on photos target', () => {
      const controller = getController();
      expect(controller.sortablePhotos).toBeDefined();
    });

    it('configures sortable with correct options', () => {
      const controller = getController();
      expect(controller.sortablePhotos.options.delay).toBe(100);
      expect(controller.sortablePhotos.options.handle).toBe('.draggable-handle');
    });
  });

  describe('addPhoto', () => {
    it('prevents default event behavior', async () => {
      mockFetchSuccess('<div class="photo-field">New Photo</div>');

      const controller = getController();
      const event = { preventDefault: vi.fn() };

      controller.addPhoto(event);

      expect(event.preventDefault).toHaveBeenCalled();
    });

    it('fetches new photo fields from endpoint', async () => {
      mockFetchSuccess('<div class="photo-field">New Photo</div>');

      const controller = getController();
      const event = { preventDefault: vi.fn() };

      controller.addPhoto(event);

      await vi.waitFor(() => {
        expect(global.fetch).toHaveBeenCalledWith(
          '/admin/entries/new/photo',
          expect.objectContaining({
            method: 'GET',
            credentials: 'include'
          })
        );
      });
    });

    it('includes CSRF token in headers', async () => {
      mockFetchSuccess('<div class="photo-field">New Photo</div>');

      const controller = getController();
      const event = { preventDefault: vi.fn() };

      controller.addPhoto(event);

      await vi.waitFor(() => {
        const headers = global.fetch.mock.calls[0][1].headers;
        expect(headers.get('X-CSRF-Token')).toBe('test-csrf-token');
      });
    });

    it('appends new photo HTML to photos target', async () => {
      mockFetchSuccess('<div class="photo-field new-photo">New Photo</div>');

      const controller = getController();
      const event = { preventDefault: vi.fn() };

      const initialCount = photosTarget().querySelectorAll('.photo-field').length;

      controller.addPhoto(event);

      await vi.waitFor(() => {
        const newCount = photosTarget().querySelectorAll('.photo-field').length;
        expect(newCount).toBe(initialCount + 1);
        expect(photosTarget().querySelector('.new-photo')).not.toBeNull();
      });
    });
  });

  describe('startSort', () => {
    it('sets mirror width to match source width', () => {
      const controller = getController();
      const mirror = document.createElement('div');
      const source = document.createElement('div');
      Object.defineProperty(source, 'clientWidth', { value: 400 });

      controller.startSort({
        data: { mirror, source }
      });

      expect(mirror.style.width).toBe('400px');
    });
  });

  describe('submit', () => {
    it('prevents default form submission', () => {
      const controller = getController();
      const mockSubmit = vi.fn();
      const event = {
        preventDefault: vi.fn(),
        target: { submit: mockSubmit }
      };

      controller.submit(event);

      expect(event.preventDefault).toHaveBeenCalled();
    });

    it('updates position fields based on DOM order', () => {
      const controller = getController();

      // Simulate reordering by swapping the inputs
      const photos = photosTarget();
      const photoFields = photos.querySelectorAll('.photo-field');
      const firstPhoto = photoFields[0];
      photos.appendChild(firstPhoto); // Move first to last

      const mockSubmit = vi.fn();
      const event = {
        preventDefault: vi.fn(),
        target: { submit: mockSubmit }
      };

      controller.submit(event);

      const inputs = positionInputs();
      // After reordering, positions should be 1 and 2 in DOM order
      expect(inputs[0].value).toBe('1');
      expect(inputs[1].value).toBe('2');
    });

    it('calls form submit after updating positions', () => {
      const controller = getController();
      const mockSubmit = vi.fn();
      const event = {
        preventDefault: vi.fn(),
        target: { submit: mockSubmit }
      };

      controller.submit(event);

      expect(mockSubmit).toHaveBeenCalled();
    });

    it('assigns sequential positions starting from 1', () => {
      // Add a third photo field
      const newPhoto = document.createElement('div');
      newPhoto.className = 'photo-field';
      newPhoto.innerHTML = '<input type="hidden" data-position value="3"><div class="draggable-handle">Photo 3</div>';
      photosTarget().appendChild(newPhoto);

      const controller = getController();
      const mockSubmit = vi.fn();
      const event = {
        preventDefault: vi.fn(),
        target: { submit: mockSubmit }
      };

      controller.submit(event);

      const inputs = positionInputs();
      expect(inputs[0].value).toBe('1');
      expect(inputs[1].value).toBe('2');
      expect(inputs[2].value).toBe('3');
    });
  });

  describe('integration', () => {
    it('handles full add and reorder flow', async () => {
      // Add a new photo
      mockFetchSuccess('<div class="photo-field"><input type="hidden" data-position value=""><div class="draggable-handle">Photo 3</div></div>');

      const controller = getController();
      const addEvent = { preventDefault: vi.fn() };

      controller.addPhoto(addEvent);

      await vi.waitFor(() => {
        expect(photosTarget().querySelectorAll('.photo-field').length).toBe(3);
      });

      // Submit the form
      const mockSubmit = vi.fn();
      const submitEvent = {
        preventDefault: vi.fn(),
        target: { submit: mockSubmit }
      };

      controller.submit(submitEvent);

      // All positions should be set correctly
      const inputs = positionInputs();
      inputs.forEach((input, index) => {
        expect(input.value).toBe(String(index + 1));
      });
    });
  });
});
