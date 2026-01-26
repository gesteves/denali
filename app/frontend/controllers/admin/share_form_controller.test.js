import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';
import ShareFormController from './share_form_controller';

describe('ShareFormController', () => {
  let application;
  let element;

  beforeEach(() => {
    global.fetch = vi.fn();

    document.body.innerHTML = `
      <form data-controller="share-form"
            data-share-form-url-value="/admin/entries/1/share/bluesky"
            data-share-form-platform-value="Bluesky">
        <textarea data-share-form-target="text">Check out my new post!</textarea>
        <input type="datetime-local" data-share-form-target="scheduledAt" value="">
        <input type="text" data-share-form-target="inReplyTo" value="">
        <input type="text" data-share-form-target="quote" value="">
        <select data-share-form-target="crop">
          <option value="">Default</option>
          <option value="1:1">Square</option>
        </select>
        <div data-share-form-target="stats"></div>
        <button data-share-form-target="submit" data-action="click->share-form#submit">Share</button>
      </form>
    `;

    element = document.querySelector('[data-controller="share-form"]');
    application = Application.start();
    application.register('share-form', ShareFormController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
    vi.clearAllMocks();
  });

  function getController() {
    return application.getControllerForElementAndIdentifier(element, 'share-form');
  }

  function submitTarget() {
    return element.querySelector('[data-share-form-target="submit"]');
  }

  function statsTarget() {
    return element.querySelector('[data-share-form-target="stats"]');
  }

  function mockFetchSuccess(data) {
    global.fetch.mockResolvedValueOnce({
      ok: true,
      json: () => Promise.resolve(data)
    });
  }

  function mockFetchError() {
    global.fetch.mockRejectedValueOnce(new Error('Network error'));
  }

  describe('submit', () => {
    it('prevents default event behavior', async () => {
      mockFetchSuccess({ status: 'success', message: 'Shared!' });

      const controller = getController();
      const event = { preventDefault: vi.fn() };

      controller.submit(event);

      expect(event.preventDefault).toHaveBeenCalled();
    });

    it('disables submit button during submission', async () => {
      mockFetchSuccess({ status: 'success', message: 'Shared!' });

      const controller = getController();
      const event = { preventDefault: vi.fn() };

      controller.submit(event);

      expect(submitTarget().disabled).toBe(true);
      expect(submitTarget().classList.contains('is-loading')).toBe(true);
    });

    it('sends POST request with form data', async () => {
      mockFetchSuccess({ status: 'success', message: 'Shared!' });

      const controller = getController();
      const event = { preventDefault: vi.fn() };

      controller.submit(event);

      await vi.waitFor(() => {
        expect(global.fetch).toHaveBeenCalledWith(
          '/admin/entries/1/share/bluesky',
          expect.objectContaining({
            method: 'POST',
            headers: expect.objectContaining({
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            })
          })
        );
      });
    });

    it('includes CSRF token in headers', async () => {
      mockFetchSuccess({ status: 'success', message: 'Shared!' });

      const controller = getController();
      const event = { preventDefault: vi.fn() };

      controller.submit(event);

      await vi.waitFor(() => {
        expect(global.fetch.mock.calls[0][1].headers['X-CSRF-Token']).toBe('test-csrf-token');
      });
    });

    it('sends notification on success', async () => {
      mockFetchSuccess({ status: 'success', message: 'Successfully shared!' });
      const dispatchSpy = vi.spyOn(document.body, 'dispatchEvent');

      const controller = getController();
      const event = { preventDefault: vi.fn() };

      controller.submit(event);

      await vi.waitFor(() => {
        const notifyEvent = dispatchSpy.mock.calls.find(call => call[0].type === 'notify');
        expect(notifyEvent).toBeDefined();
        expect(notifyEvent[0].detail.message).toBe('Successfully shared!');
        expect(notifyEvent[0].detail.status).toBe('success');
      });
    });

    it('re-enables submit button after completion', async () => {
      mockFetchSuccess({ status: 'success', message: 'Shared!' });

      const controller = getController();
      const event = { preventDefault: vi.fn() };

      controller.submit(event);

      await vi.waitFor(() => {
        expect(submitTarget().disabled).toBe(false);
        expect(submitTarget().classList.contains('is-loading')).toBe(false);
      });
    });

    it('shows error notification on fetch error', async () => {
      mockFetchError();
      const dispatchSpy = vi.spyOn(document.body, 'dispatchEvent');

      const controller = getController();
      const event = { preventDefault: vi.fn() };

      controller.submit(event);

      await vi.waitFor(() => {
        const notifyEvent = dispatchSpy.mock.calls.find(call => call[0].type === 'notify');
        expect(notifyEvent).toBeDefined();
        expect(notifyEvent[0].detail.status).toBe('danger');
        expect(notifyEvent[0].detail.message).toContain('Bluesky');
      });
    });

    it('updates stats on success with last_shared_at', async () => {
      mockFetchSuccess({
        status: 'success',
        message: 'Shared!',
        last_shared_at: '2024-01-15T10:30:00Z',
        shares_count: 5
      });

      const controller = getController();
      const event = { preventDefault: vi.fn() };

      controller.submit(event);

      await vi.waitFor(() => {
        expect(statsTarget().innerHTML).toContain('Last shared');
        expect(statsTarget().innerHTML).toContain('just now');
        expect(statsTarget().innerHTML).toContain('5');
      });
    });

    it('does not update stats if scheduled', async () => {
      mockFetchSuccess({
        status: 'success',
        message: 'Scheduled!',
        last_shared_at: '2024-01-15T10:30:00Z',
        shares_count: 5,
        scheduled: true
      });

      const controller = getController();
      const event = { preventDefault: vi.fn() };

      controller.submit(event);

      await vi.waitFor(() => {
        expect(statsTarget().innerHTML).not.toContain('Last shared');
      });
    });
  });

  describe('buildFormData', () => {
    it('includes text when text target exists', () => {
      const controller = getController();

      const data = controller.buildFormData();

      expect(data.text).toBe('Check out my new post!');
    });

    it('includes scheduledAt when target has value', () => {
      element.querySelector('[data-share-form-target="scheduledAt"]').value = '2024-01-20T15:00';

      const controller = getController();

      const data = controller.buildFormData();

      expect(data.scheduled_at).toBe('2024-01-20T15:00');
    });

    it('includes inReplyTo when target has value', () => {
      element.querySelector('[data-share-form-target="inReplyTo"]').value = 'at://did:plc:abc/post/123';

      const controller = getController();

      const data = controller.buildFormData();

      expect(data.in_reply_to).toBe('at://did:plc:abc/post/123');
    });

    it('includes quote when target has value', () => {
      element.querySelector('[data-share-form-target="quote"]').value = 'at://did:plc:xyz/post/456';

      const controller = getController();

      const data = controller.buildFormData();

      expect(data.quote).toBe('at://did:plc:xyz/post/456');
    });

    it('includes crop when target has value', () => {
      element.querySelector('[data-share-form-target="crop"]').value = '1:1';

      const controller = getController();

      const data = controller.buildFormData();

      expect(data.crop).toBe('1:1');
    });

    it('handles missing optional targets', () => {
      // Remove optional targets
      element.querySelector('[data-share-form-target="scheduledAt"]').remove();
      element.querySelector('[data-share-form-target="inReplyTo"]').remove();

      // Get controller (targets are already removed, Stimulus handles missing targets)
      const controller = getController();

      const data = controller.buildFormData();

      expect(data.text).toBe('Check out my new post!');
      expect(data.scheduled_at).toBeUndefined();
      expect(data.in_reply_to).toBeUndefined();
    });
  });

  describe('notify', () => {
    it('dispatches notify event with status and message', () => {
      const dispatchSpy = vi.spyOn(document.body, 'dispatchEvent');
      const controller = getController();

      controller.notify('warning', 'Something happened');

      expect(dispatchSpy).toHaveBeenCalledWith(expect.any(CustomEvent));
      const event = dispatchSpy.mock.calls[0][0];
      expect(event.type).toBe('notify');
      expect(event.detail.status).toBe('warning');
      expect(event.detail.message).toBe('Something happened');
      expect(event.bubbles).toBe(true);
    });
  });
});
