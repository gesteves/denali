import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';

// Track Pagination calls
const observeCalls = [];
const unobserveCalls = [];

vi.mock('../../observers/pagination', () => ({
  default: {
    observe: vi.fn((el) => observeCalls.push(el)),
    unobserve: vi.fn((el) => unobserveCalls.push(el))
  }
}));

import PaginationController from './pagination_controller';
import Pagination from '../../observers/pagination';

describe('PaginationController', () => {
  let application;
  let element;

  beforeEach(() => {
    vi.clearAllMocks();
    observeCalls.length = 0;
    unobserveCalls.length = 0;

    document.body.innerHTML = `
      <div data-controller="pagination"
           data-pagination-page-url="/page/2">
        <article>Entry content</article>
      </div>
    `;

    element = document.querySelector('[data-controller="pagination"]');
    application = Application.start();
    application.register('pagination', PaginationController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
    vi.clearAllMocks();
  });

  function getController() {
    return application.getControllerForElementAndIdentifier(element, 'pagination');
  }

  describe('connect', () => {
    it('calls Pagination.observe with element', () => {
      expect(observeCalls.length).toBe(1);
      expect(observeCalls[0]).toBe(element);
    });

    it('calls observe exactly once', () => {
      expect(observeCalls.length).toBe(1);
    });
  });

  describe('disconnect', () => {
    it('calls Pagination.unobserve with element on disconnect', () => {
      const controller = getController();
      controller.disconnect();
      expect(Pagination.unobserve).toHaveBeenCalledWith(element);
    });
  });
});
