import { Controller } from 'stimulus';
import { fetchStatus, fetchJson, sendNotification } from '../../lib/utils';

/**
 * Controls the alt text review UI for approving AI-generated alt text.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['currentAltText', 'generatedAltText', 'generateButton', 'saveButton', 'generatedField', 'saveButtonContainer', 'dismissButton', 'dismissButtonContainer'];
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
        sendNotification('Alt text generated.', 'success');
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
   * Saves the approved alt text.
   * @param {Event} event Click event from the save button.
   */
  save (event) {
    event.preventDefault();
    this.saveButtonTarget.classList.add('is-loading');
    this.saveButtonTarget.disabled = true;

    const fetchOpts = {
      method: 'POST',
      headers: new Headers({
        'X-CSRF-Token': this.csrfToken,
        'Accept': 'application/json',
        'Content-Type': 'application/json'
      }),
      credentials: 'include',
      body: JSON.stringify({ text: this.generatedAltTextTarget.value })
    };

    fetch(this.approveUrlValue, fetchOpts)
      .then(fetchStatus)
      .then(fetchJson)
      .then(json => {
        this.currentAltTextTarget.textContent = json.alt_text;
        this.generatedFieldTarget.classList.add('is-hidden');
        this.saveButtonContainerTarget.classList.add('is-hidden');
        this.dismissButtonContainerTarget.classList.add('is-hidden');
        sendNotification('Alt text saved.', 'success');
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
        this.saveButtonContainerTarget.classList.add('is-hidden');
        this.dismissButtonContainerTarget.classList.add('is-hidden');
        sendNotification('Alt text dismissed.', 'success');
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
