import { describe, it, expect, vi, beforeEach } from 'vitest';
import { fetchStatus, fetchJson, fetchText, sendNotification, supportsHover } from './utils';

describe('fetchStatus', () => {
  it('resolves with response when response.ok is true', async () => {
    const response = { ok: true, status: 200 };
    const result = await fetchStatus(response);
    expect(result).toBe(response);
  });

  it('rejects when response.ok is false', async () => {
    const response = { ok: false, status: 404 };
    await expect(fetchStatus(response)).rejects.toBeUndefined();
  });

  it('rejects for 500 error responses', async () => {
    const response = { ok: false, status: 500 };
    await expect(fetchStatus(response)).rejects.toBeUndefined();
  });
});

describe('fetchJson', () => {
  it('returns parsed JSON from response', async () => {
    const data = { message: 'success', count: 42 };
    const response = { json: () => Promise.resolve(data) };
    const result = await fetchJson(response);
    expect(result).toEqual(data);
  });

  it('handles arrays', async () => {
    const data = [1, 2, 3];
    const response = { json: () => Promise.resolve(data) };
    const result = await fetchJson(response);
    expect(result).toEqual([1, 2, 3]);
  });

  it('handles nested objects', async () => {
    const data = { user: { name: 'John', settings: { theme: 'dark' } } };
    const response = { json: () => Promise.resolve(data) };
    const result = await fetchJson(response);
    expect(result).toEqual(data);
  });
});

describe('fetchText', () => {
  it('returns text from response', async () => {
    const text = '<html>Hello World</html>';
    const response = { text: () => Promise.resolve(text) };
    const result = await fetchText(response);
    expect(result).toBe(text);
  });

  it('handles empty strings', async () => {
    const response = { text: () => Promise.resolve('') };
    const result = await fetchText(response);
    expect(result).toBe('');
  });

  it('handles multiline text', async () => {
    const text = 'Line 1\nLine 2\nLine 3';
    const response = { text: () => Promise.resolve(text) };
    const result = await fetchText(response);
    expect(result).toBe(text);
  });
});

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
