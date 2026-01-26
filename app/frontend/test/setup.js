import { vi } from 'vitest';

// Mock IntersectionObserver
class MockIntersectionObserver {
  constructor(callback) {
    this.callback = callback;
    this.elements = new Set();
  }

  observe(element) {
    this.elements.add(element);
  }

  unobserve(element) {
    this.elements.delete(element);
  }

  disconnect() {
    this.elements.clear();
  }

  // Helper to trigger intersection
  trigger(entries) {
    this.callback(entries, this);
  }
}

global.IntersectionObserver = MockIntersectionObserver;

// Mock ResizeObserver
class MockResizeObserver {
  constructor(callback) {
    this.callback = callback;
    this.elements = new Set();
  }

  observe(element) {
    this.elements.add(element);
  }

  unobserve(element) {
    this.elements.delete(element);
  }

  disconnect() {
    this.elements.clear();
  }
}

global.ResizeObserver = MockResizeObserver;

// Mock MutationObserver
class MockMutationObserver {
  constructor(callback) {
    this.callback = callback;
  }

  observe() {}
  disconnect() {}
  takeRecords() { return []; }
}

global.MutationObserver = MockMutationObserver;

// Mock navigator.serviceWorker
const mockPushSubscription = {
  endpoint: 'https://example.com/push',
  getKey: vi.fn(() => new ArrayBuffer(0)),
  toJSON: vi.fn(() => ({
    endpoint: 'https://example.com/push',
    keys: { p256dh: 'key1', auth: 'key2' }
  })),
  unsubscribe: vi.fn(() => Promise.resolve(true))
};

const mockPushManager = {
  getSubscription: vi.fn(() => Promise.resolve(null)),
  subscribe: vi.fn(() => Promise.resolve(mockPushSubscription))
};

const mockServiceWorkerRegistration = {
  pushManager: mockPushManager,
  active: { state: 'activated' },
  installing: null,
  waiting: null,
  scope: '/'
};

if (!navigator.serviceWorker) {
  Object.defineProperty(navigator, 'serviceWorker', {
    value: {
      ready: Promise.resolve(mockServiceWorkerRegistration),
      register: vi.fn(() => Promise.resolve(mockServiceWorkerRegistration)),
      getRegistration: vi.fn(() => Promise.resolve(mockServiceWorkerRegistration)),
      getRegistrations: vi.fn(() => Promise.resolve([mockServiceWorkerRegistration]))
    },
    configurable: true
  });
}

// Mock Notification API
global.Notification = {
  permission: 'default',
  requestPermission: vi.fn(() => Promise.resolve('granted'))
};

// Mock window.matchMedia
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: vi.fn().mockImplementation(query => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn()
  }))
});

// Mock window.history
const mockHistory = {
  pushState: vi.fn(),
  replaceState: vi.fn(),
  back: vi.fn(),
  forward: vi.fn(),
  go: vi.fn()
};

Object.defineProperty(window, 'history', {
  value: mockHistory,
  writable: true
});

// Setup CSRF meta tag
function setupCSRFToken(token = 'test-csrf-token') {
  let metaTag = document.querySelector('[name=csrf-token]');
  if (!metaTag) {
    metaTag = document.createElement('meta');
    metaTag.name = 'csrf-token';
    metaTag.content = token;
    document.head.appendChild(metaTag);
  } else {
    metaTag.content = token;
  }
}

// Automatically setup CSRF token before each test
beforeEach(() => {
  setupCSRFToken();
});

// Clean up after each test
afterEach(() => {
  document.body.innerHTML = '';
  vi.clearAllMocks();
});

// Mock fetch globally
global.fetch = vi.fn();

// Mock plausible analytics
global.plausible = vi.fn();

// Mock window.confirm
window.confirm = vi.fn(() => true);

// Mock window.prompt
window.prompt = vi.fn(() => 'test input');

// Export mocks for use in tests
export {
  MockIntersectionObserver,
  MockResizeObserver,
  MockMutationObserver,
  mockPushSubscription,
  mockPushManager,
  mockServiceWorkerRegistration,
  setupCSRFToken
};
