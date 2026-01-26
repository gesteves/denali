import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';
import TagController from './tag_controller';

describe('TagController', () => {
  let application;
  let element;

  beforeEach(() => {
    global.fetch = vi.fn();
    window.prompt = vi.fn(() => 'test input');
    window.confirm = vi.fn(() => true);

    document.body.innerHTML = `
      <div id="wrapper">
        <div data-controller="tag" data-tag-name-value="Nature">
          <a href="/admin/tags/1/add" data-action="click->tag#add">Add</a>
          <a href="/admin/tags/1" data-action="click->tag#edit">Edit</a>
          <a href="/admin/tags/1" data-action="click->tag#delete">Delete</a>
        </div>
      </div>
    `;

    element = document.querySelector('[data-controller="tag"]');
    application = Application.start();
    application.register('tag', TagController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
    vi.clearAllMocks();
  });

  function getController() {
    return application.getControllerForElementAndIdentifier(element, 'tag');
  }

  function mockFetchSuccess(data) {
    global.fetch.mockResolvedValueOnce({
      ok: true,
      text: () => Promise.resolve(typeof data === 'string' ? data : JSON.stringify(data)),
      json: () => Promise.resolve(data)
    });
  }

  describe('connect', () => {
    it('retrieves CSRF token from meta tag', () => {
      const controller = getController();
      expect(controller.csrfToken).toBe('test-csrf-token');
    });
  });

  describe('add', () => {
    it('shows prompt asking for tag name', () => {
      const controller = getController();
      const event = {
        preventDefault: vi.fn(),
        target: element.querySelector('[data-action*="add"]')
      };

      mockFetchSuccess({ message: 'Tag added', status: 'success' });
      controller.add(event);

      expect(window.prompt).toHaveBeenCalled();
      const promptArg = window.prompt.mock.calls[0][0];
      expect(promptArg).toContain('Nature');
      expect(promptArg).toContain('tag');
    });

    it('returns early when prompt is cancelled (null)', () => {
      window.prompt = vi.fn(() => null);

      const controller = getController();
      const event = {
        preventDefault: vi.fn(),
        target: element.querySelector('[data-action*="add"]')
      };

      controller.add(event);

      expect(global.fetch).not.toHaveBeenCalled();
    });

    it('returns early when prompt is empty string', () => {
      window.prompt = vi.fn(() => '');

      const controller = getController();
      const event = {
        preventDefault: vi.fn(),
        target: element.querySelector('[data-action*="add"]')
      };

      controller.add(event);

      expect(global.fetch).not.toHaveBeenCalled();
    });

    it('returns early when prompt is only whitespace', () => {
      window.prompt = vi.fn(() => '   ');

      const controller = getController();
      const event = {
        preventDefault: vi.fn(),
        target: element.querySelector('[data-action*="add"]')
      };

      controller.add(event);

      expect(global.fetch).not.toHaveBeenCalled();
    });

    it('sends POST request with tag data', async () => {
      window.prompt = vi.fn(() => 'Wildlife');
      mockFetchSuccess({ message: 'Tag added', status: 'success' });

      const controller = getController();
      const link = element.querySelector('[data-action*="add"]');
      const event = { preventDefault: vi.fn(), target: link };

      controller.add(event);

      await vi.waitFor(() => {
        expect(global.fetch).toHaveBeenCalledWith(
          expect.stringContaining('/admin/tags/1/add.json'),
          expect.objectContaining({
            method: 'POST',
            body: JSON.stringify({ tags: 'Wildlife' })
          })
        );
      });
    });

    it('includes CSRF token in headers', async () => {
      mockFetchSuccess({ message: 'Tag added', status: 'success' });

      const controller = getController();
      const link = element.querySelector('[data-action*="add"]');
      const event = { preventDefault: vi.fn(), target: link };

      controller.add(event);

      await vi.waitFor(() => {
        const headers = global.fetch.mock.calls[0][1].headers;
        expect(headers.get('X-CSRF-Token')).toBe('test-csrf-token');
      });
    });

    it('sends notification on success', async () => {
      mockFetchSuccess({ message: 'Tag added successfully', status: 'success' });
      const dispatchSpy = vi.spyOn(document.body, 'dispatchEvent');

      const controller = getController();
      const link = element.querySelector('[data-action*="add"]');
      const event = { preventDefault: vi.fn(), target: link };

      controller.add(event);

      await vi.waitFor(() => {
        const notifyEvent = dispatchSpy.mock.calls.find(call => call[0].type === 'notify');
        expect(notifyEvent).toBeDefined();
        expect(notifyEvent[0].detail.message).toBe('Tag added successfully');
      });
    });
  });

  describe('edit', () => {
    it('shows prompt with current tag name as default value', () => {
      const controller = getController();
      const event = {
        preventDefault: vi.fn(),
        target: element.querySelector('[data-action*="edit"]')
      };

      mockFetchSuccess('<div>Updated tag</div>');
      controller.edit(event);

      expect(window.prompt).toHaveBeenCalled();
      const promptArg = window.prompt.mock.calls[0][0];
      expect(promptArg).toContain('Nature');
      expect(promptArg).toContain('rename');
    });

    it('returns early when prompt is cancelled (null)', () => {
      window.prompt = vi.fn(() => null);

      const controller = getController();
      const event = {
        preventDefault: vi.fn(),
        target: element.querySelector('[data-action*="edit"]')
      };

      controller.edit(event);

      expect(global.fetch).not.toHaveBeenCalled();
    });

    it('returns early when prompt is empty string', () => {
      window.prompt = vi.fn(() => '');

      const controller = getController();
      const event = {
        preventDefault: vi.fn(),
        target: element.querySelector('[data-action*="edit"]')
      };

      controller.edit(event);

      expect(global.fetch).not.toHaveBeenCalled();
    });

    it('returns early when prompt is only whitespace', () => {
      window.prompt = vi.fn(() => '   ');

      const controller = getController();
      const event = {
        preventDefault: vi.fn(),
        target: element.querySelector('[data-action*="edit"]')
      };

      controller.edit(event);

      expect(global.fetch).not.toHaveBeenCalled();
    });

    it('sends PATCH request with new name', async () => {
      window.prompt = vi.fn(() => 'Wildlife');
      mockFetchSuccess('<div>Updated tag</div>');

      const controller = getController();
      const link = element.querySelector('[data-action*="edit"]');
      const event = { preventDefault: vi.fn(), target: link };

      controller.edit(event);

      await vi.waitFor(() => {
        expect(global.fetch).toHaveBeenCalledWith(
          expect.stringContaining('/admin/tags/1.json'),
          expect.objectContaining({
            method: 'PATCH',
            body: JSON.stringify({ name: 'Wildlife' })
          })
        );
      });
    });

    it('includes CSRF token in headers', async () => {
      mockFetchSuccess('<div>Updated tag</div>');

      const controller = getController();
      const link = element.querySelector('[data-action*="edit"]');
      const event = { preventDefault: vi.fn(), target: link };

      controller.edit(event);

      await vi.waitFor(() => {
        const headers = global.fetch.mock.calls[0][1].headers;
        expect(headers.get('X-CSRF-Token')).toBe('test-csrf-token');
      });
    });

    it('replaces element HTML on success', async () => {
      window.prompt = vi.fn(() => 'Wildlife');
      mockFetchSuccess('<div data-controller="tag" data-tag-name-value="Wildlife">Updated</div>');

      const controller = getController();
      const link = element.querySelector('[data-action*="edit"]');
      const event = { preventDefault: vi.fn(), target: link };

      controller.edit(event);

      await vi.waitFor(() => {
        const newElement = document.querySelector('[data-tag-name-value="Wildlife"]');
        expect(newElement).not.toBeNull();
      });
    });
  });

  describe('delete', () => {
    it('shows confirmation dialog', () => {
      window.confirm = vi.fn(() => false); // Return false to prevent deletion

      const controller = getController();
      const event = {
        preventDefault: vi.fn(),
        target: element.querySelector('[data-action*="delete"]')
      };

      controller.delete(event);

      expect(window.confirm).toHaveBeenCalled();
      const confirmArg = window.confirm.mock.calls[0][0];
      expect(confirmArg).toContain('Nature');
      expect(confirmArg).toContain('delete');
    });

    it('returns early when confirmation is cancelled', () => {
      window.confirm = vi.fn(() => false);

      const controller = getController();
      const event = {
        preventDefault: vi.fn(),
        target: element.querySelector('[data-action*="delete"]')
      };

      controller.delete(event);

      expect(global.fetch).not.toHaveBeenCalled();
    });

    it('sends DELETE request', async () => {
      window.confirm = vi.fn(() => true);
      mockFetchSuccess({ message: 'Tag deleted', status: 'success' });

      const controller = getController();
      const link = element.querySelector('[data-action*="delete"]');
      const event = { preventDefault: vi.fn(), target: link };

      controller.delete(event);

      await vi.waitFor(() => {
        expect(global.fetch).toHaveBeenCalledWith(
          expect.stringContaining('/admin/tags/1.json'),
          expect.objectContaining({
            method: 'DELETE'
          })
        );
      });
    });

    it('includes CSRF token in headers', async () => {
      window.confirm = vi.fn(() => true);
      mockFetchSuccess({ message: 'Tag deleted', status: 'success' });

      const controller = getController();
      const link = element.querySelector('[data-action*="delete"]');
      const event = { preventDefault: vi.fn(), target: link };

      controller.delete(event);

      await vi.waitFor(() => {
        const headers = global.fetch.mock.calls[0][1].headers;
        expect(headers.get('X-CSRF-Token')).toBe('test-csrf-token');
      });
    });

    it('removes element from DOM on success', async () => {
      window.confirm = vi.fn(() => true);
      mockFetchSuccess({ message: 'Tag deleted', status: 'success' });

      const controller = getController();
      const link = element.querySelector('[data-action*="delete"]');
      const event = { preventDefault: vi.fn(), target: link };

      controller.delete(event);

      await vi.waitFor(() => {
        const deletedElement = document.querySelector('[data-controller="tag"]');
        expect(deletedElement).toBeNull();
      });
    });

    it('sends notification on success', async () => {
      window.confirm = vi.fn(() => true);
      mockFetchSuccess({ message: 'Tag deleted successfully', status: 'success' });
      const dispatchSpy = vi.spyOn(document.body, 'dispatchEvent');

      const controller = getController();
      const link = element.querySelector('[data-action*="delete"]');
      const event = { preventDefault: vi.fn(), target: link };

      controller.delete(event);

      await vi.waitFor(() => {
        const notifyEvent = dispatchSpy.mock.calls.find(call => call[0].type === 'notify');
        expect(notifyEvent).toBeDefined();
        expect(notifyEvent[0].detail.message).toBe('Tag deleted successfully');
      });
    });
  });
});
