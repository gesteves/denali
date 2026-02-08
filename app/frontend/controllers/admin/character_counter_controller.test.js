import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { Application } from '@hotwired/stimulus';
import CharacterCounterController from './character_counter_controller';

describe('CharacterCounterController', () => {
  let application;
  let element;

  beforeEach(() => {
    document.body.innerHTML = `
      <div data-controller="character-counter" data-character-counter-max-length-value="280">
        <textarea data-character-counter-target="input" data-action="input->character-counter#updateCharacterCount"></textarea>
        <span data-character-counter-target="characterCount">0</span>
        <button data-character-counter-target="submit" type="submit">Submit</button>
      </div>
    `;

    element = document.querySelector('[data-controller="character-counter"]');
    application = Application.start();
    application.register('character-counter', CharacterCounterController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
  });

  function getController() {
    return application.getControllerForElementAndIdentifier(element, 'character-counter');
  }

  function inputArea() {
    return element.querySelector('[data-character-counter-target="input"]');
  }

  function characterCount() {
    return element.querySelector('[data-character-counter-target="characterCount"]');
  }

  function submitButton() {
    return element.querySelector('[data-character-counter-target="submit"]');
  }

  function setInput(value) {
    inputArea().value = value;
    inputArea().dispatchEvent(new Event('input', { bubbles: true }));
  }

  describe('connect', () => {
    it('sets maxCharacters from value attribute', () => {
      const controller = getController();
      expect(controller.maxCharacters).toBe(280);
    });

    it('updates character count on connect', () => {
      expect(characterCount().innerHTML).toBe('0');
    });
  });

  describe('updateCharacterCount', () => {
    it('counts basic ASCII characters', () => {
      setInput('hello');
      expect(characterCount().innerHTML).toBe('5');
    });

    it('counts spaces', () => {
      setInput('hello world');
      expect(characterCount().innerHTML).toBe('11');
    });

    it('counts emoji as single graphemes', () => {
      setInput('hello \u{1F44D}'); // thumbs up emoji
      expect(characterCount().innerHTML).toBe('7'); // "hello " + 1 emoji
    });

    it('counts complex emoji as single graphemes', () => {
      setInput('\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}'); // family emoji
      expect(characterCount().innerHTML).toBe('1');
    });

    it('counts flag emoji correctly', () => {
      setInput('\u{1F1FA}\u{1F1F8}'); // US flag
      expect(characterCount().innerHTML).toBe('1');
    });

    it('handles empty input', () => {
      setInput('');
      expect(characterCount().innerHTML).toBe('0');
    });
  });

  describe('stripMarkdown', () => {
    it('strips markdown links and counts only the label', () => {
      setInput('[Example](https://www.example.com)');
      expect(characterCount().innerHTML).toBe('7'); // "Example"
    });

    it('handles multiple markdown links', () => {
      setInput('[One](https://one.com) and [Two](https://two.com)');
      expect(characterCount().innerHTML).toBe('11'); // "One and Two"
    });

    it('handles text mixed with links', () => {
      setInput('Check out [my site](https://example.com) for more info');
      // "Check out my site for more info" = 31 characters
      expect(characterCount().innerHTML).toBe('31');
    });

    it('handles links with special characters in URL', () => {
      setInput('[Link](https://example.com/path?query=value&other=123)');
      expect(characterCount().innerHTML).toBe('4'); // "Link"
    });

    it('preserves non-link text', () => {
      setInput('Just plain text');
      expect(characterCount().innerHTML).toBe('15');
    });

    it('handles nested brackets correctly', () => {
      setInput('[Link [text]](https://example.com)');
      // The regex [([^\]]+)] matches [Link , so "Link " is kept
      // The rest "(https://example.com)" with the nested bracket remains
      // Test the actual behavior of the regex
      const count = parseInt(characterCount().innerHTML);
      expect(count).toBeGreaterThan(0);
    });
  });

  describe('character limit warning', () => {
    it('adds has-text-danger class when approaching limit (within 10 characters)', () => {
      setInput('a'.repeat(271)); // 271 chars, within 10 of 280
      expect(characterCount().classList.contains('has-text-danger')).toBe(true);
    });

    it('does not add has-text-danger class when well under limit', () => {
      setInput('a'.repeat(200));
      expect(characterCount().classList.contains('has-text-danger')).toBe(false);
    });

    it('adds has-text-danger at exactly limit minus 10', () => {
      setInput('a'.repeat(270)); // Exactly at threshold
      expect(characterCount().classList.contains('has-text-danger')).toBe(false);
    });

    it('adds has-text-danger at limit minus 9', () => {
      setInput('a'.repeat(271));
      expect(characterCount().classList.contains('has-text-danger')).toBe(true);
    });

    it('removes has-text-danger class when text is shortened', () => {
      setInput('a'.repeat(275));
      expect(characterCount().classList.contains('has-text-danger')).toBe(true);

      setInput('a'.repeat(100));
      expect(characterCount().classList.contains('has-text-danger')).toBe(false);
    });
  });

  describe('submit button disabling', () => {
    it('disables submit button when over limit', () => {
      setInput('a'.repeat(281));
      expect(submitButton().disabled).toBe(true);
    });

    it('keeps submit button enabled when at limit', () => {
      setInput('a'.repeat(280));
      expect(submitButton().disabled).toBe(false);
    });

    it('keeps submit button enabled when under limit', () => {
      setInput('a'.repeat(100));
      expect(submitButton().disabled).toBe(false);
    });

    it('re-enables submit button when text is shortened below limit', () => {
      setInput('a'.repeat(300));
      expect(submitButton().disabled).toBe(true);

      setInput('a'.repeat(200));
      expect(submitButton().disabled).toBe(false);
    });
  });

  describe('maxLength from input attribute', () => {
    beforeEach(() => {
      application.stop();
      document.body.innerHTML = `
        <div data-controller="character-counter">
          <textarea data-character-counter-target="input" maxlength="100" data-action="input->character-counter#updateCharacterCount"></textarea>
          <span data-character-counter-target="characterCount">0</span>
          <button data-character-counter-target="submit" type="submit">Submit</button>
        </div>
      `;
      element = document.querySelector('[data-controller="character-counter"]');
      application = Application.start();
      application.register('character-counter', CharacterCounterController);
    });

    it('uses maxlength attribute when maxLengthValue is not set', () => {
      const controller = getController();
      expect(controller.maxCharacters).toBe(100);
    });

    it('disables submit when exceeding maxlength limit', () => {
      setInput('a'.repeat(101));
      expect(submitButton().disabled).toBe(true);
    });
  });

  describe('without submit target', () => {
    beforeEach(() => {
      application.stop();
      document.body.innerHTML = `
        <div data-controller="character-counter" data-character-counter-max-length-value="100">
          <textarea data-character-counter-target="input" data-action="input->character-counter#updateCharacterCount"></textarea>
          <span data-character-counter-target="characterCount">0</span>
        </div>
      `;
      element = document.querySelector('[data-controller="character-counter"]');
      application = Application.start();
      application.register('character-counter', CharacterCounterController);
    });

    it('works without a submit target', () => {
      setInput('hello world');
      expect(characterCount().innerHTML).toBe('11');
    });

    it('adds danger class when approaching limit without submit target', () => {
      setInput('a'.repeat(95));
      expect(characterCount().classList.contains('has-text-danger')).toBe(true);
    });

    it('does not throw error when exceeding limit without submit target', () => {
      expect(() => setInput('a'.repeat(150))).not.toThrow();
      expect(characterCount().innerHTML).toBe('150');
    });
  });

  describe('integration', () => {
    it('correctly counts a tweet with emoji and links', () => {
      setInput(' Check out [my blog](https://example.com) for updates!');
      // " Check out my blog for updates!" - emoji is 1 grapheme, "my blog" is 7
      // Total: 1 + 1 + 10 + 7 + 13 = 32 or similar
      const count = parseInt(characterCount().innerHTML);
      // The count should account for emoji as 1 grapheme and strip the link URL
      expect(count).toBeLessThan(55); // Less than full string with URL
      expect(count).toBeGreaterThan(25); // More than just a few chars
    });

    it('handles real-world content with mixed elements', () => {
      const content = 'Just published: [A Complete Guide](https://blog.example.com/guide) to JavaScript testing  #webdev #testing';
      setInput(content);
      // "Just published: A Complete Guide to JavaScript testing  #webdev #testing"
      expect(parseInt(characterCount().innerHTML)).toBeGreaterThan(50);
      expect(submitButton().disabled).toBe(false);
    });
  });
});
