import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';

// No utils functions needed - modal_controller uses async/await directly
vi.mock('../../lib/utils', () => ({}));

import ModalController from './modal_controller';

describe('ModalController', () => {
  let application;
  let element;

  beforeEach(() => {
    global.fetch = vi.fn();

    document.body.innerHTML = `
      <a data-controller="modal"
         href="/admin/photos/1/edit"
         data-action="click->modal#open">
        Edit Photo
      </a>
    `;

    element = document.querySelector('[data-controller="modal"]');
    application = Application.start();
    application.register('modal', ModalController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
    vi.clearAllMocks();
  });

  function getController() {
    return application.getControllerForElementAndIdentifier(element, 'modal');
  }

  function mockFetchSuccess(html) {
    global.fetch.mockResolvedValueOnce({
      ok: true,
      text: () => Promise.resolve(html)
    });
  }

  function mockFetchError() {
    global.fetch.mockResolvedValueOnce({
      ok: false,
      status: 500,
      statusText: 'Internal Server Error'
    });
  }

  describe('connect', () => {
    it('retrieves CSRF token from meta tag', () => {
      const controller = getController();
      expect(controller.csrfToken).toBe('test-csrf-token');
    });
  });

  describe('open', () => {
    it('prevents default event behavior', async () => {
      mockFetchSuccess('<div class="modal">Modal content</div>');

      const controller = getController();
      const event = { preventDefault: vi.fn() };

      controller.open(event);

      expect(event.preventDefault).toHaveBeenCalled();
    });

    it('fetches modal content from element href with modal=true param', async () => {
      mockFetchSuccess('<div class="modal">Modal content</div>');

      const controller = getController();
      const event = { preventDefault: vi.fn() };

      controller.open(event);

      await vi.waitFor(() => {
        expect(global.fetch).toHaveBeenCalled();
        const url = global.fetch.mock.calls[0][0];
        expect(url).toContain('/admin/photos/1/edit');
        expect(url).toContain('modal=true');
      });
    });

    it('includes CSRF token in headers', async () => {
      mockFetchSuccess('<div class="modal">Modal content</div>');

      const controller = getController();
      const event = { preventDefault: vi.fn() };

      controller.open(event);

      await vi.waitFor(() => {
        const headers = global.fetch.mock.calls[0][1].headers;
        expect(headers.get('X-CSRF-Token')).toBe('test-csrf-token');
      });
    });

    it('inserts modal HTML into document body', async () => {
      mockFetchSuccess('<div class="modal" id="test-modal">Modal content</div>');

      const controller = getController();
      const event = { preventDefault: vi.fn() };

      controller.open(event);

      await vi.waitFor(() => {
        expect(document.querySelector('#test-modal')).not.toBeNull();
        expect(document.querySelector('#test-modal').textContent).toBe('Modal content');
      });
    });

    it('appends modal at end of body', async () => {
      mockFetchSuccess('<div class="modal" id="test-modal">Modal content</div>');

      const controller = getController();
      const event = { preventDefault: vi.fn() };

      controller.open(event);

      await vi.waitFor(() => {
        const modal = document.querySelector('#test-modal');
        expect(modal.parentNode).toBe(document.body);
        expect(document.body.lastElementChild).toBe(modal);
      });
    });
  });

  describe('close', () => {
    beforeEach(() => {
      // Set up modal element that will be closed
      document.body.innerHTML = `
        <div class="modal" data-controller="modal">
          <div class="modal-background" data-action="click->modal#close"></div>
          <div class="modal-content">Content</div>
          <button class="modal-close" data-action="click->modal#close"></button>
        </div>
      `;

      element = document.querySelector('[data-controller="modal"]');
      application.stop();
      application = Application.start();
      application.register('modal', ModalController);
    });

    it('prevents default event behavior', () => {
      const controller = getController();
      const event = { preventDefault: vi.fn() };

      controller.close(event);

      expect(event.preventDefault).toHaveBeenCalled();
    });

    it('removes modal element from DOM', () => {
      const controller = getController();
      const event = { preventDefault: vi.fn() };

      expect(document.querySelector('.modal')).not.toBeNull();

      controller.close(event);

      expect(document.querySelector('.modal')).toBeNull();
    });
  });
});
