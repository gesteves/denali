import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';
import InlineFormController from './inline_form_controller';

describe('InlineFormController', () => {
  let application;
  let element;

  beforeEach(() => {
    document.body.innerHTML = `
      <div data-controller="inline-form">
        <div data-inline-form-target="placeholder">
          <button type="button" class="button is-info is-outlined" data-action="inline-form#show">
            Add Bluesky Account
          </button>
        </div>

        <template data-inline-form-target="template">
          <form class="box" data-inline-form-target="form">
            <div class="field">
              <label class="label">Handle</label>
              <input type="text" class="input" name="handle">
            </div>
            <div class="field is-grouped">
              <button type="submit" class="button is-success">Connect</button>
              <button type="button" class="button" data-action="inline-form#hide">Cancel</button>
            </div>
          </form>
        </template>
      </div>
    `;

    element = document.querySelector('[data-controller="inline-form"]');
    application = Application.start();
    application.register('inline-form', InlineFormController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
  });

  function getController() {
    return application.getControllerForElementAndIdentifier(element, 'inline-form');
  }

  describe('show', () => {
    it('replaces placeholder with template content', () => {
      const controller = getController();
      const placeholder = element.querySelector('[data-inline-form-target="placeholder"]');

      expect(placeholder).not.toBeNull();
      expect(element.querySelector('form')).toBeNull();

      controller.show();

      expect(element.querySelector('[data-inline-form-target="placeholder"]')).toBeNull();
      expect(element.querySelector('form')).not.toBeNull();
    });

    it('shows the form with all fields', () => {
      const controller = getController();
      controller.show();

      const form = element.querySelector('form');
      expect(form).not.toBeNull();
      expect(form.querySelector('input[name="handle"]')).not.toBeNull();
      expect(form.querySelector('button[type="submit"]')).not.toBeNull();
    });

    it('includes cancel button that calls hide', () => {
      const controller = getController();
      controller.show();

      const cancelButton = element.querySelector('button[data-action="inline-form#hide"]');
      expect(cancelButton).not.toBeNull();
      expect(cancelButton.textContent).toContain('Cancel');
    });
  });

  describe('hide', () => {
    beforeEach(() => {
      // First show the form
      const controller = getController();
      controller.show();
    });

    it('replaces form with placeholder', () => {
      const controller = getController();
      expect(element.querySelector('form')).not.toBeNull();

      controller.hide();

      expect(element.querySelector('form')).toBeNull();
      expect(element.querySelector('[data-inline-form-target="placeholder"]')).not.toBeNull();
    });

    it('restores the add button', () => {
      const controller = getController();
      controller.hide();

      const button = element.querySelector('button[data-action="inline-form#show"]');
      expect(button).not.toBeNull();
      expect(button.textContent).toContain('Add Bluesky Account');
    });
  });

  describe('targets', () => {
    it('has template target', () => {
      const controller = getController();
      expect(controller.templateTarget).not.toBeNull();
    });

    it('has placeholder target initially', () => {
      const controller = getController();
      expect(controller.placeholderTarget).not.toBeNull();
    });

    it('has form target after show', () => {
      const controller = getController();
      controller.show();
      expect(controller.formTarget).not.toBeNull();
    });
  });
});
