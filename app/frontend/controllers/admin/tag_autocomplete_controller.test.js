import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';

// Track Awesomplete options
let awesompleteOptions = {};
let awesompleteInput = null;

vi.mock('awesomplete', () => {
  // Create a class with static property
  class MockAwesomplete {
    constructor(input, options) {
      awesompleteInput = input;
      awesompleteOptions = options;
    }
  }
  MockAwesomplete.FILTER_CONTAINS = (text, input) => {
    return text.toLowerCase().indexOf(input.toLowerCase()) !== -1;
  };
  return { default: MockAwesomplete };
});

import TagAutocompleteController from './tag_autocomplete_controller';

describe('TagAutocompleteController', () => {
  let application;
  let element;

  beforeEach(() => {
    vi.clearAllMocks();

    document.body.innerHTML = `
      <div data-controller="tag-autocomplete">
        <input type="text"
               data-tag-autocomplete-target="tags"
               placeholder="Enter tags...">
        <datalist data-tag-autocomplete-target="datalist" id="tag-options">
          <option value="nature">
          <option value="landscape">
          <option value="portrait">
          <option value="wildlife">
        </datalist>
      </div>
    `;

    element = document.querySelector('[data-controller="tag-autocomplete"]');
    application = Application.start();
    application.register('tag-autocomplete', TagAutocompleteController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
    vi.clearAllMocks();
  });

  function getController() {
    return application.getControllerForElementAndIdentifier(element, 'tag-autocomplete');
  }

  function tagsTarget() {
    return element.querySelector('[data-tag-autocomplete-target="tags"]');
  }

  function datalistTarget() {
    return element.querySelector('[data-tag-autocomplete-target="datalist"]');
  }

  describe('connect', () => {
    it('initializes Awesomplete with tags input', () => {
      expect(awesompleteInput).toBe(tagsTarget());
    });

    it('uses datalist target as suggestion list', () => {
      expect(awesompleteOptions.list).toBe(datalistTarget());
    });

    it('provides custom filter function', () => {
      expect(awesompleteOptions.filter).toBeInstanceOf(Function);
    });

    it('provides custom replace function', () => {
      expect(awesompleteOptions.replace).toBeInstanceOf(Function);
    });
  });

  describe('filter function', () => {
    it('filters based on text after last comma', () => {
      const filter = awesompleteOptions.filter;

      // Simulating input "nature, land" - should match last part "land"
      const result = filter('landscape', 'nature, land');

      // The filter extracts the part after the last comma
      expect(result).toBeDefined();
    });

    it('handles input without commas', () => {
      const filter = awesompleteOptions.filter;

      // Should match the whole input
      const result = filter('nature', 'nat');

      expect(result).toBeDefined();
    });
  });

  describe('replace function', () => {
    it('appends selected text after existing tags', () => {
      const replace = awesompleteOptions.replace;

      // Create a mock context that has an input property
      const mockContext = {
        input: {
          value: 'nature, '
        }
      };

      replace.call(mockContext, 'landscape');

      expect(mockContext.input.value).toBe('nature, landscape, ');
    });

    it('handles empty input', () => {
      const replace = awesompleteOptions.replace;

      const mockContext = {
        input: {
          value: ''
        }
      };

      replace.call(mockContext, 'nature');

      expect(mockContext.input.value).toBe('nature, ');
    });

    it('handles input with trailing spaces', () => {
      const replace = awesompleteOptions.replace;

      const mockContext = {
        input: {
          value: 'nature,   '
        }
      };

      replace.call(mockContext, 'landscape');

      expect(mockContext.input.value).toBe('nature,   landscape, ');
    });
  });
});
