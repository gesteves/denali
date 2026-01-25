import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { Application } from '@hotwired/stimulus';
import SluggifierController from './sluggifier_controller';

describe('SluggifierController', () => {
  let application;
  let element;

  beforeEach(() => {
    document.body.innerHTML = `
      <div data-controller="sluggifier">
        <input type="text" data-sluggifier-target="title" data-action="input->sluggifier#handleTitleChange">
        <input type="text" data-sluggifier-target="slug" data-action="input->sluggifier#handleSlugChange">
      </div>
    `;

    element = document.querySelector('[data-controller="sluggifier"]');
    application = Application.start();
    application.register('sluggifier', SluggifierController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
  });

  function getController() {
    return application.getControllerForElementAndIdentifier(element, 'sluggifier');
  }

  function titleInput() {
    return element.querySelector('[data-sluggifier-target="title"]');
  }

  function slugInput() {
    return element.querySelector('[data-sluggifier-target="slug"]');
  }

  function setTitle(value) {
    titleInput().value = value;
    titleInput().dispatchEvent(new Event('input', { bubbles: true }));
  }

  function setSlug(value) {
    slugInput().value = value;
    slugInput().dispatchEvent(new Event('input', { bubbles: true }));
  }

  describe('connect', () => {
    it('sets isSlugEditable to true when slug is empty', () => {
      const controller = getController();
      expect(controller.isSlugEditable).toBe(true);
    });

    it('sets isSlugEditable to false when slug has a value', async () => {
      application.stop();
      document.body.innerHTML = '';

      // Create new element with pre-filled slug
      document.body.innerHTML = `
        <div data-controller="sluggifier">
          <input type="text" data-sluggifier-target="title" data-action="input->sluggifier#handleTitleChange">
          <input type="text" data-sluggifier-target="slug" data-action="input->sluggifier#handleSlugChange" value="existing-slug">
        </div>
      `;

      element = document.querySelector('[data-controller="sluggifier"]');
      application = Application.start();
      application.register('sluggifier', SluggifierController);

      // Wait for Stimulus to connect
      await new Promise(resolve => setTimeout(resolve, 10));

      const controller = application.getControllerForElementAndIdentifier(element, 'sluggifier');
      expect(controller.isSlugEditable).toBe(false);
    });
  });

  describe('handleTitleChange', () => {
    it('updates slug when slug is editable', () => {
      setTitle('Hello World');
      expect(slugInput().value).toBe('hello-world');
    });

    it('does not update slug when slug is not editable', () => {
      setSlug('custom-slug');
      setTitle('Hello World');
      expect(slugInput().value).toBe('custom-slug');
    });

    it('does not update slug when title is empty', () => {
      setTitle('');
      expect(slugInput().value).toBe('');
    });

    it('does not update slug when title is whitespace only', () => {
      setTitle('   ');
      expect(slugInput().value).toBe('');
    });
  });

  describe('handleSlugChange', () => {
    it('makes slug non-editable when slug has a value', () => {
      const controller = getController();
      expect(controller.isSlugEditable).toBe(true);

      setSlug('my-custom-slug');
      expect(controller.isSlugEditable).toBe(false);
    });

    it('makes slug editable again when slug is cleared', () => {
      const controller = getController();

      setSlug('my-custom-slug');
      expect(controller.isSlugEditable).toBe(false);

      setSlug('');
      expect(controller.isSlugEditable).toBe(true);
    });
  });

  describe('parameterize', () => {
    it('converts string to lowercase', () => {
      const controller = getController();
      expect(controller.parameterize('HELLO')).toBe('hello');
    });

    it('replaces spaces with hyphens', () => {
      const controller = getController();
      expect(controller.parameterize('hello world')).toBe('hello-world');
    });

    it('removes special characters', () => {
      const controller = getController();
      expect(controller.parameterize('hello!@#$%world')).toBe('hello-world');
    });

    it('handles multiple consecutive spaces', () => {
      const controller = getController();
      expect(controller.parameterize('hello    world')).toBe('hello-world');
    });

    it('removes leading hyphens', () => {
      const controller = getController();
      expect(controller.parameterize('---hello')).toBe('hello');
    });

    it('removes trailing hyphens', () => {
      const controller = getController();
      expect(controller.parameterize('hello---')).toBe('hello');
    });

    it('replaces multiple consecutive hyphens with single hyphen', () => {
      const controller = getController();
      expect(controller.parameterize('hello---world')).toBe('hello-world');
    });

    it('preserves underscores', () => {
      const controller = getController();
      expect(controller.parameterize('hello_world')).toBe('hello_world');
    });

    it('preserves existing hyphens', () => {
      const controller = getController();
      expect(controller.parameterize('hello-world')).toBe('hello-world');
    });

    it('handles complex strings', () => {
      const controller = getController();
      expect(controller.parameterize('  Hello, World! How are you?  ')).toBe('hello-world-how-are-you');
    });

    it('handles numbers', () => {
      const controller = getController();
      expect(controller.parameterize('test 123 abc')).toBe('test-123-abc');
    });

    it('handles emoji and unicode by removing them', () => {
      const controller = getController();
      expect(controller.parameterize('hello world')).toBe('hello-world');
    });

    it('handles accented characters by removing them', () => {
      const controller = getController();
      expect(controller.parameterize('café résumé')).toBe('caf-r-sum');
    });
  });

  describe('integration', () => {
    it('generates slug from title on initial input', () => {
      setTitle('My First Blog Post');
      expect(slugInput().value).toBe('my-first-blog-post');
    });

    it('allows manual slug override', () => {
      setTitle('My First Blog Post');
      expect(slugInput().value).toBe('my-first-blog-post');

      setSlug('custom-url');
      setTitle('Updated Title');
      expect(slugInput().value).toBe('custom-url');
    });

    it('resumes auto-generation after clearing manual slug', () => {
      setSlug('custom-url');
      setTitle('New Title');
      expect(slugInput().value).toBe('custom-url');

      setSlug('');
      setTitle('Another Title');
      expect(slugInput().value).toBe('another-title');
    });
  });
});
