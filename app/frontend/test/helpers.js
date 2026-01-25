import { Application } from '@hotwired/stimulus';
import { vi } from 'vitest';

/**
 * Creates a Stimulus application with a registered controller.
 * @param {string} identifier - The controller identifier (e.g., 'sluggifier')
 * @param {class} controllerClass - The Stimulus controller class
 * @returns {Application} - The Stimulus application instance
 */
export function createApplication(identifier, controllerClass) {
  const application = Application.start();
  application.register(identifier, controllerClass);
  return application;
}

/**
 * Connects a Stimulus controller to a DOM element and returns the controller instance.
 * @param {HTMLElement} element - The DOM element to attach the controller to
 * @param {string} identifier - The controller identifier
 * @param {class} controllerClass - The Stimulus controller class
 * @returns {Promise<{application: Application, controller: Controller}>} - The app and controller
 */
export async function connectController(element, identifier, controllerClass) {
  // Ensure element has the data-controller attribute
  element.setAttribute('data-controller', identifier);
  document.body.appendChild(element);

  const application = createApplication(identifier, controllerClass);

  // Wait for Stimulus to connect the controller
  await new Promise(resolve => setTimeout(resolve, 0));

  const controller = application.getControllerForElementAndIdentifier(element, identifier);

  return { application, controller };
}

/**
 * Creates a mock fetch Response object.
 * @param {any} data - The response data
 * @param {Object} options - Additional response options
 * @param {boolean} options.ok - Whether the response is ok (default: true)
 * @param {number} options.status - The HTTP status code (default: 200)
 * @param {Object} options.headers - Response headers
 * @returns {Response} - A mock Response object
 */
export function mockFetchResponse(data, options = {}) {
  const { ok = true, status = 200, headers = {} } = options;

  return {
    ok,
    status,
    headers: new Headers(headers),
    json: () => Promise.resolve(data),
    text: () => Promise.resolve(typeof data === 'string' ? data : JSON.stringify(data)),
    clone: function() { return this; }
  };
}

/**
 * Sets up global fetch to return a mocked response.
 * @param {any} data - The response data
 * @param {Object} options - Response options passed to mockFetchResponse
 */
export function setupMockFetch(data, options = {}) {
  global.fetch = vi.fn(() => Promise.resolve(mockFetchResponse(data, options)));
}

/**
 * Sets up global fetch to reject with an error.
 * @param {Error} error - The error to reject with
 */
export function setupMockFetchError(error = new Error('Network error')) {
  global.fetch = vi.fn(() => Promise.reject(error));
}

/**
 * Sets up global fetch to return an HTTP error response.
 * @param {number} status - The HTTP status code
 * @param {any} data - Optional response data
 */
export function setupMockFetchHttpError(status = 404, data = null) {
  global.fetch = vi.fn(() => Promise.resolve(mockFetchResponse(data, { ok: false, status })));
}

/**
 * Creates an IntersectionObserverEntry-like object for testing.
 * @param {HTMLElement} target - The observed element
 * @param {boolean} isIntersecting - Whether the element is intersecting
 * @param {number} intersectionRatio - The intersection ratio (0-1)
 * @returns {Object} - An IntersectionObserverEntry-like object
 */
export function createIntersectionEntry(target, isIntersecting, intersectionRatio = isIntersecting ? 1 : 0) {
  return {
    target,
    isIntersecting,
    intersectionRatio,
    boundingClientRect: target.getBoundingClientRect(),
    intersectionRect: isIntersecting ? target.getBoundingClientRect() : { top: 0, bottom: 0, left: 0, right: 0, width: 0, height: 0 },
    rootBounds: null,
    time: Date.now()
  };
}

/**
 * Waits for a specified number of milliseconds.
 * @param {number} ms - Milliseconds to wait
 * @returns {Promise} - A promise that resolves after the delay
 */
export function wait(ms = 0) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Waits for the next microtask to complete.
 * @returns {Promise} - A promise that resolves on the next microtask
 */
export function flushPromises() {
  return new Promise(resolve => setImmediate(resolve));
}

/**
 * Creates a basic HTML element with targets for a Stimulus controller.
 * @param {string} identifier - The controller identifier
 * @param {string} html - The inner HTML of the element
 * @returns {HTMLElement} - The configured element
 */
export function createControllerElement(identifier, html) {
  const element = document.createElement('div');
  element.setAttribute('data-controller', identifier);
  element.innerHTML = html;
  return element;
}

/**
 * Simulates an input event on an element.
 * @param {HTMLElement} element - The input element
 * @param {string} value - The new value
 */
export function simulateInput(element, value) {
  element.value = value;
  element.dispatchEvent(new Event('input', { bubbles: true }));
}

/**
 * Simulates a change event on an element.
 * @param {HTMLElement} element - The input element
 * @param {string} value - The new value
 */
export function simulateChange(element, value) {
  element.value = value;
  element.dispatchEvent(new Event('change', { bubbles: true }));
}

/**
 * Simulates a click event on an element.
 * @param {HTMLElement} element - The element to click
 */
export function simulateClick(element) {
  element.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
}

/**
 * Disconnects a Stimulus application and cleans up.
 * @param {Application} application - The Stimulus application to stop
 */
export function disconnectApplication(application) {
  application.stop();
}
