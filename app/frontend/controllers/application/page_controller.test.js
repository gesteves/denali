import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';
import PageController from './page_controller';
import * as analytics from '../../lib/analytics';

// Mock the analytics module
vi.mock('../../lib/analytics', () => ({
  trackPageView: vi.fn()
}));

describe('PageController', () => {
  let application;
  let element;

  beforeEach(() => {
    vi.clearAllMocks();

    document.body.innerHTML = `
      <div data-controller="page">
        <h1>Page Content</h1>
      </div>
    `;

    element = document.querySelector('[data-controller="page"]');
    application = Application.start();
    application.register('page', PageController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
  });

  describe('connect', () => {
    it('calls trackPageView on connect', () => {
      expect(analytics.trackPageView).toHaveBeenCalled();
    });

    it('calls trackPageView exactly once', () => {
      expect(analytics.trackPageView).toHaveBeenCalledTimes(1);
    });
  });
});
