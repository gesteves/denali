import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';
import SharingSettingsController from './sharing_settings_controller';

describe('SharingSettingsController', () => {
  let application;
  let element;

  beforeEach(() => {
    global.fetch = vi.fn();

    document.body.innerHTML = `
      <div data-controller="sharing-settings"
           data-sharing-settings-url-value="/admin/entries/1/sharing_settings">
        <input type="hidden" data-sharing-settings-target="blueskyField" value="true">
        <input type="hidden" data-sharing-settings-target="mastodonField" value="false">
        <input type="hidden" data-sharing-settings-target="instagramField" value="true">
        <input type="hidden" data-sharing-settings-target="threadsField" value="false">
        <button data-action="click->sharing-settings#save">Save</button>
      </div>
    `;

    element = document.querySelector('[data-controller="sharing-settings"]');
    application = Application.start();
    application.register('sharing-settings', SharingSettingsController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
    vi.clearAllMocks();
  });

  function getController() {
    return application.getControllerForElementAndIdentifier(element, 'sharing-settings');
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

  describe('save', () => {
    it('sends POST request with sharing settings', async () => {
      mockFetchSuccess({ status: 'success', message: 'Settings saved' });

      const controller = getController();

      controller.save();

      await vi.waitFor(() => {
        expect(global.fetch).toHaveBeenCalledWith(
          '/admin/entries/1/sharing_settings',
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
      mockFetchSuccess({ status: 'success', message: 'Settings saved' });

      const controller = getController();

      controller.save();

      await vi.waitFor(() => {
        expect(global.fetch.mock.calls[0][1].headers['X-CSRF-Token']).toBe('test-csrf-token');
      });
    });

    it('sends correct boolean values based on field values', async () => {
      mockFetchSuccess({ status: 'success', message: 'Settings saved' });

      const controller = getController();

      controller.save();

      await vi.waitFor(() => {
        const body = JSON.parse(global.fetch.mock.calls[0][1].body);
        expect(body.entry.post_to_bluesky).toBe(true);
        expect(body.entry.post_to_mastodon).toBe(false);
        expect(body.entry.post_to_instagram).toBe(true);
        expect(body.entry.post_to_threads).toBe(false);
      });
    });

    it('converts string "true" to boolean true', async () => {
      mockFetchSuccess({ status: 'success', message: 'Settings saved' });

      const controller = getController();

      controller.save();

      await vi.waitFor(() => {
        const body = JSON.parse(global.fetch.mock.calls[0][1].body);
        expect(body.entry.post_to_bluesky).toBe(true);
        expect(typeof body.entry.post_to_bluesky).toBe('boolean');
      });
    });

    it('converts string "false" to boolean false', async () => {
      mockFetchSuccess({ status: 'success', message: 'Settings saved' });

      const controller = getController();

      controller.save();

      await vi.waitFor(() => {
        const body = JSON.parse(global.fetch.mock.calls[0][1].body);
        expect(body.entry.post_to_mastodon).toBe(false);
        expect(typeof body.entry.post_to_mastodon).toBe('boolean');
      });
    });

    it('sends notification on success', async () => {
      mockFetchSuccess({ status: 'success', message: 'Sharing settings saved!' });
      const dispatchSpy = vi.spyOn(document.body, 'dispatchEvent');

      const controller = getController();

      controller.save();

      await vi.waitFor(() => {
        const notifyEvent = dispatchSpy.mock.calls.find(call => call[0].type === 'notify');
        expect(notifyEvent).toBeDefined();
        expect(notifyEvent[0].detail.message).toBe('Sharing settings saved!');
        expect(notifyEvent[0].detail.status).toBe('success');
      });
    });

    it('shows error notification on fetch error', async () => {
      mockFetchError();
      const dispatchSpy = vi.spyOn(document.body, 'dispatchEvent');

      const controller = getController();

      controller.save();

      await vi.waitFor(() => {
        const notifyEvent = dispatchSpy.mock.calls.find(call => call[0].type === 'notify');
        expect(notifyEvent).toBeDefined();
        expect(notifyEvent[0].detail.status).toBe('danger');
        expect(notifyEvent[0].detail.message).toContain('Failed to save sharing settings');
      });
    });
  });

  describe('notify', () => {
    it('dispatches notify event with status and message', () => {
      const dispatchSpy = vi.spyOn(document.body, 'dispatchEvent');
      const controller = getController();

      controller.notify('info', 'Test notification');

      expect(dispatchSpy).toHaveBeenCalledWith(expect.any(CustomEvent));
      const event = dispatchSpy.mock.calls[0][0];
      expect(event.type).toBe('notify');
      expect(event.detail.status).toBe('info');
      expect(event.detail.message).toBe('Test notification');
      expect(event.bubbles).toBe(true);
    });
  });
});
