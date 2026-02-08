import { describe, it, expect, vi, beforeEach } from 'vitest';
import { sendNotification, supportsHover } from './utils';

describe('sendNotification', () => {
  beforeEach(() => {
    vi.spyOn(document.body, 'dispatchEvent');
  });

  it('dispatches a custom notify event with message and default success status', () => {
    sendNotification('Test message');

    expect(document.body.dispatchEvent).toHaveBeenCalledTimes(1);

    const event = document.body.dispatchEvent.mock.calls[0][0];
    expect(event.type).toBe('notify');
    expect(event.detail.message).toBe('Test message');
    expect(event.detail.status).toBe('success');
  });

  it('dispatches a notify event with custom status', () => {
    sendNotification('Error occurred', 'danger');

    const event = document.body.dispatchEvent.mock.calls[0][0];
    expect(event.detail.message).toBe('Error occurred');
    expect(event.detail.status).toBe('danger');
  });

  it('dispatches a notify event with warning status', () => {
    sendNotification('Warning!', 'warning');

    const event = document.body.dispatchEvent.mock.calls[0][0];
    expect(event.detail.status).toBe('warning');
  });
});

describe('supportsHover', () => {
  it('returns true when device supports hover', () => {
    window.matchMedia = vi.fn().mockImplementation(query => ({
      matches: query === '(hover: hover)',
      media: query
    }));

    expect(supportsHover()).toBe(true);
  });

  it('returns false when device does not support hover', () => {
    window.matchMedia = vi.fn().mockImplementation(query => ({
      matches: false,
      media: query
    }));

    expect(supportsHover()).toBe(false);
  });
});
