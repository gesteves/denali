import { Controller } from '@hotwired/stimulus';
import { fetchStatus, fetchJson, sendNotification } from '../../lib/utils';

/**
 * Controls the alt text review UI for approving AI-generated alt text.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['currentAltText', 'generatedAltText', 'generateButton', 'saveButton', 'generatedField', 'saveButtonContainer', 'dismissButton', 'dismissButtonContainer', 'editButton', 'editButtonContainer', 'editField', 'editAltText', 'generateButtonContainer'];
  static values = {
    generateUrl: String,
    approveUrl: String,
    dismissUrl: String
  }

  connect () {
    this.csrfToken = document.querySelector('[name=csrf-token]').getAttribute('content');
  }

  /**
   * Generates AI alt text for the photo.
   * @param {Event} event Click event from the generate button.
   */
  generate (event) {
    event.preventDefault();
    this.generateButtonTarget.classList.add('is-loading');
    this.generateButtonTarget.disabled = true;

    const fetchOpts = {
      method: 'POST',
      headers: new Headers({
        'X-CSRF-Token': this.csrfToken,
        'Accept': 'application/json'
      }),
      credentials: 'include'
    };

    fetch(this.generateUrlValue, fetchOpts)
      .then(fetchStatus)
      .then(fetchJson)
      .then(json => {
        this.generatedAltTextTarget.value = json.auto_generated_alt_text;
        this.generatedFieldTarget.classList.remove('is-hidden');
        this.saveButtonContainerTarget.classList.remove('is-hidden');
        this.dismissButtonContainerTarget.classList.remove('is-hidden');
        this.editButtonContainerTarget.classList.add('is-hidden');
      })
      .catch(() => {
        sendNotification('Failed to generate alt text.', 'danger');
      })
      .finally(() => {
        this.generateButtonTarget.classList.remove('is-loading');
        this.generateButtonTarget.disabled = false;
      });
  }

  /**
   * Opens the edit mode for directly editing the current alt text.
   * @param {Event} event Click event from the edit button.
   */
  edit (event) {
    event.preventDefault();
    // Copy current text to edit textarea
    this.editAltTextTarget.value = this.currentAltTextTarget.textContent.trim();
    // Show edit field, hide current alt text display
    this.editFieldTarget.classList.remove('is-hidden');
    this.currentAltTextTarget.parentElement.classList.add('is-hidden');
    // Hide Generate and Edit buttons
    this.generateButtonContainerTarget.classList.add('is-hidden');
    this.editButtonContainerTarget.classList.add('is-hidden');
    // Show Dismiss and Save buttons
    this.dismissButtonContainerTarget.classList.remove('is-hidden');
    this.saveButtonContainerTarget.classList.remove('is-hidden');
  }

  /**
   * Checks if the controller is in edit mode (editing current alt text directly).
   * @returns {boolean} True if in edit mode.
   */
  isInEditMode () {
    return !this.editFieldTarget.classList.contains('is-hidden');
  }

  /**
   * Saves the approved alt text.
   * @param {Event} event Click event from the save button.
   */
  save (event) {
    event.preventDefault();
    this.saveButtonTarget.classList.add('is-loading');
    this.saveButtonTarget.disabled = true;

    const inEditMode = this.isInEditMode();
    const textValue = inEditMode ? this.editAltTextTarget.value : this.generatedAltTextTarget.value;

    const fetchOpts = {
      method: 'POST',
      headers: new Headers({
        'X-CSRF-Token': this.csrfToken,
        'Accept': 'application/json',
        'Content-Type': 'application/json'
      }),
      credentials: 'include',
      body: JSON.stringify({ text: textValue })
    };

    fetch(this.approveUrlValue, fetchOpts)
      .then(fetchStatus)
      .then(fetchJson)
      .then(json => {
        this.currentAltTextTarget.textContent = json.alt_text;
        this.generatedFieldTarget.classList.add('is-hidden');
        this.editFieldTarget.classList.add('is-hidden');
        this.currentAltTextTarget.parentElement.classList.remove('is-hidden');
        this.saveButtonContainerTarget.classList.add('is-hidden');
        this.dismissButtonContainerTarget.classList.add('is-hidden');
        this.generateButtonContainerTarget.classList.remove('is-hidden');
        this.editButtonContainerTarget.classList.remove('is-hidden');
      })
      .catch(() => {
        sendNotification('Failed to save alt text.', 'danger');
      })
      .finally(() => {
        this.saveButtonTarget.classList.remove('is-loading');
        this.saveButtonTarget.disabled = false;
      });
  }

  /**
   * Dismisses the AI-generated alt text without saving.
   * @param {Event} event Click event from the dismiss button.
   */
  dismiss (event) {
    event.preventDefault();
    this.dismissButtonTarget.classList.add('is-loading');
    this.dismissButtonTarget.disabled = true;

    const fetchOpts = {
      method: 'POST',
      headers: new Headers({
        'X-CSRF-Token': this.csrfToken,
        'Accept': 'application/json'
      }),
      credentials: 'include'
    };

    fetch(this.dismissUrlValue, fetchOpts)
      .then(fetchStatus)
      .then(fetchJson)
      .then(() => {
        this.generatedFieldTarget.classList.add('is-hidden');
        this.editFieldTarget.classList.add('is-hidden');
        this.currentAltTextTarget.parentElement.classList.remove('is-hidden');
        this.saveButtonContainerTarget.classList.add('is-hidden');
        this.dismissButtonContainerTarget.classList.add('is-hidden');
        this.generateButtonContainerTarget.classList.remove('is-hidden');
        this.editButtonContainerTarget.classList.remove('is-hidden');
      })
      .catch(() => {
        sendNotification('Failed to dismiss alt text.', 'danger');
      })
      .finally(() => {
        this.dismissButtonTarget.classList.remove('is-loading');
        this.dismissButtonTarget.disabled = false;
      });
  }
}
