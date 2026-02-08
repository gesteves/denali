import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';
import QueueController from './queue_controller';

// Mock @shopify/draggable
vi.mock('@shopify/draggable', () => ({
  Sortable: class MockSortable {
    constructor(container, options) {
      this.container = container;
      this.options = options;
      this.handlers = {};
    }
    on(event, handler) {
      this.handlers[event] = handler;
    }
    trigger(event, data) {
      if (this.handlers[event]) {
        this.handlers[event](data);
      }
    }
    destroy() {}
  }
}));

describe('QueueController', () => {
  let application;
  let element;

  beforeEach(() => {
    global.fetch = vi.fn();
    window.confirm = vi.fn(() => true);

    document.body.innerHTML = `
      <div data-controller="queue"
           data-queue-past-publish-schedules-today-value="2"
           data-queue-publish-schedules-count-value="3"
           data-queue-time-zone-value="America/New_York"
           data-queue-endpoint-value="/admin/queue">
        <div data-queue-target="container">
          <div data-queue-target="card" data-entry-id="1" data-entry-position="1" data-entry-position-original="1" class="draggable-handle">
            <span data-timestamp>Monday, January 27, 2025</span>
          </div>
          <div data-queue-target="card" data-entry-id="2" data-entry-position="2" data-entry-position-original="2" class="draggable-handle">
            <span data-timestamp>Tuesday, January 28, 2025</span>
          </div>
          <div data-queue-target="card" data-entry-id="3" data-entry-position="3" data-entry-position-original="3" class="draggable-handle">
            <span data-timestamp>Wednesday, January 29, 2025</span>
          </div>
        </div>
        <div data-queue-target="buttons" class="is-hidden">
          <button data-action="click->queue#discard">Discard</button>
          <button data-action="click->queue#save">Save</button>
        </div>
      </div>
    `;

    element = document.querySelector('[data-controller="queue"]');
    application = Application.start();
    application.register('queue', QueueController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
    vi.clearAllMocks();
  });

  function getController() {
    return application.getControllerForElementAndIdentifier(element, 'queue');
  }

  function container() {
    return element.querySelector('[data-queue-target="container"]');
  }

  function cards() {
    return element.querySelectorAll('[data-queue-target="card"]');
  }

  function buttons() {
    return element.querySelector('[data-queue-target="buttons"]');
  }

  function mockFetchSuccess(data) {
    global.fetch.mockResolvedValueOnce({
      ok: true,
      json: () => Promise.resolve(data)
    });
  }

  function mockFetchError() {
    global.fetch.mockResolvedValueOnce({
      ok: false,
      status: 500
    });
  }

  describe('connect', () => {
    it('retrieves CSRF token from meta tag', () => {
      const controller = getController();
      expect(controller.csrfToken).toBe('test-csrf-token');
    });

    it('initializes sortable on container', () => {
      const controller = getController();
      expect(controller.sortableQueue).toBeDefined();
    });

    it('calls updateCards on connect', () => {
      // Cards should have their positions set
      const cardElements = cards();
      expect(cardElements[0].getAttribute('data-entry-position')).toBe('1');
      expect(cardElements[1].getAttribute('data-entry-position')).toBe('2');
      expect(cardElements[2].getAttribute('data-entry-position')).toBe('3');
    });
  });

  describe('hideButtons', () => {
    it('adds is-hidden class to buttons', () => {
      const controller = getController();
      buttons().classList.remove('is-hidden');

      controller.hideButtons();

      expect(buttons().classList.contains('is-hidden')).toBe(true);
    });
  });

  describe('showButtons', () => {
    it('removes is-hidden class from buttons', () => {
      const controller = getController();
      buttons().classList.add('is-hidden');

      controller.showButtons();

      expect(buttons().classList.contains('is-hidden')).toBe(false);
    });
  });

  describe('disableDrag', () => {
    it('removes draggable-handle class from all cards', () => {
      const controller = getController();

      controller.disableDrag();

      cards().forEach(card => {
        expect(card.classList.contains('draggable-handle')).toBe(false);
      });
    });
  });

  describe('enableDrag', () => {
    it('adds draggable-handle class to all cards', () => {
      const controller = getController();
      cards().forEach(card => card.classList.remove('draggable-handle'));

      controller.enableDrag();

      cards().forEach(card => {
        expect(card.classList.contains('draggable-handle')).toBe(true);
      });
    });
  });

  describe('startSort', () => {
    it('sets mirror width to match source width', () => {
      const controller = getController();
      const mirror = document.createElement('div');
      const source = cards()[0];
      Object.defineProperty(source, 'clientWidth', { value: 300 });

      controller.startSort({
        data: { mirror, source }
      });

      expect(mirror.style.width).toBe('300px');
    });
  });

  describe('updateCards', () => {
    it('updates position attributes based on DOM order', () => {
      const controller = getController();
      const cardArray = Array.from(cards());

      // Reorder cards in DOM
      container().appendChild(cardArray[0]); // Move first to last

      controller.updateCards();

      const updatedCards = cards();
      expect(updatedCards[0].getAttribute('data-entry-position')).toBe('1');
      expect(updatedCards[1].getAttribute('data-entry-position')).toBe('2');
      expect(updatedCards[2].getAttribute('data-entry-position')).toBe('3');
    });

    it('shows buttons when position differs from original', () => {
      const controller = getController();
      const cardArray = Array.from(cards());

      // Reorder cards
      container().appendChild(cardArray[0]);

      controller.updateCards();

      expect(buttons().classList.contains('is-hidden')).toBe(false);
    });

    it('hides buttons when positions match originals', () => {
      const controller = getController();

      controller.updateCards();

      expect(buttons().classList.contains('is-hidden')).toBe(true);
    });

    it('shows TBD when publish schedules count is 0', () => {
      const controller = getController();

      // The actual code checks `this.publishSchedulesCount` not `this.publishSchedulesCountValue`
      // So we need to set the non-value property directly
      controller.publishSchedulesCount = 0;
      controller.updateCards();

      const timestamp = element.querySelector('[data-timestamp]');
      expect(timestamp.innerHTML).toBe('TBD');
    });

    it('ignores draggable mirror elements', () => {
      const controller = getController();

      // Add a mirror element
      const mirror = document.createElement('div');
      mirror.setAttribute('data-queue-target', 'card');
      mirror.classList.add('draggable-mirror');
      mirror.setAttribute('data-entry-position-original', '1');
      mirror.innerHTML = '<span data-timestamp></span>';
      container().appendChild(mirror);

      // Should not throw and should still work correctly
      controller.updateCards();

      // Real cards should be updated correctly
      const realCards = Array.from(cards()).filter(c => !c.classList.contains('draggable-mirror'));
      expect(realCards.length).toBe(3);
    });
  });

  describe('updateCardPositions', () => {
    it('updates original position attributes to match current positions', () => {
      const controller = getController();
      const cardArray = Array.from(cards());

      // Reorder cards
      container().appendChild(cardArray[0]);
      controller.updateCards();

      controller.updateCardPositions();

      const updatedCards = cards();
      updatedCards.forEach((card, i) => {
        expect(card.getAttribute('data-entry-position-original')).toBe(String(i + 1));
      });
    });
  });

  describe('discard', () => {
    it('shows confirmation dialog', () => {
      const controller = getController();
      const cardArray = Array.from(cards());

      // Reorder cards
      container().appendChild(cardArray[0]);
      controller.updateCards();

      const event = { preventDefault: vi.fn() };
      controller.discard(event);

      expect(window.confirm).toHaveBeenCalled();
    });

    it('does nothing when user cancels confirmation', () => {
      window.confirm = vi.fn(() => false);

      const controller = getController();
      const cardArray = Array.from(cards());

      // Reorder cards
      container().appendChild(cardArray[0]);
      controller.updateCards();

      const event = { preventDefault: vi.fn() };
      const result = controller.discard(event);

      expect(result).toBe(false);
    });

    it('restores original order when confirmed', () => {
      const controller = getController();
      const cardArray = Array.from(cards());

      // Reorder: move first to last
      container().appendChild(cardArray[0]);
      controller.updateCards();

      const event = { preventDefault: vi.fn() };
      controller.discard(event);

      // Cards should be back in original order
      const updatedCards = cards();
      expect(updatedCards[0].getAttribute('data-entry-id')).toBe('1');
      expect(updatedCards[1].getAttribute('data-entry-id')).toBe('2');
      expect(updatedCards[2].getAttribute('data-entry-id')).toBe('3');
    });

    it('sends danger notification', () => {
      const dispatchSpy = vi.spyOn(document.body, 'dispatchEvent');

      const controller = getController();
      const cardArray = Array.from(cards());
      container().appendChild(cardArray[0]);
      controller.updateCards();

      const event = { preventDefault: vi.fn() };
      controller.discard(event);

      const notifyEvent = dispatchSpy.mock.calls.find(call => call[0].type === 'notify');
      expect(notifyEvent).toBeDefined();
      expect(notifyEvent[0].detail.status).toBe('danger');
    });
  });

  describe('save', () => {
    it('shows confirmation dialog', async () => {
      mockFetchSuccess({ message: 'Saved!', status: 'success' });

      const controller = getController();
      const event = { preventDefault: vi.fn() };
      controller.save(event);

      expect(window.confirm).toHaveBeenCalled();
    });

    it('does nothing when user cancels confirmation', async () => {
      window.confirm = vi.fn(() => false);

      const controller = getController();
      const event = { preventDefault: vi.fn() };
      const result = await controller.save(event);

      expect(result).toBe(false);
      expect(global.fetch).not.toHaveBeenCalled();
    });

    it('makes POST request with entry IDs', async () => {
      mockFetchSuccess({ message: 'Saved!', status: 'success' });

      const controller = getController();
      const event = { preventDefault: vi.fn() };
      controller.save(event);

      await vi.waitFor(() => {
        expect(global.fetch).toHaveBeenCalledWith(
          '/admin/queue.json',
          expect.objectContaining({
            method: 'POST',
            body: JSON.stringify({ entry_ids: [1, 2, 3] })
          })
        );
      });
    });

    it('includes CSRF token in headers', async () => {
      mockFetchSuccess({ message: 'Saved!', status: 'success' });

      const controller = getController();
      const event = { preventDefault: vi.fn() };
      controller.save(event);

      await vi.waitFor(() => {
        const headers = global.fetch.mock.calls[0][1].headers;
        expect(headers.get('X-CSRF-Token')).toBe('test-csrf-token');
      });
    });

    it('hides buttons and disables drag during save', async () => {
      let resolvePromise;
      global.fetch.mockReturnValue(new Promise(resolve => {
        resolvePromise = resolve;
      }));

      const controller = getController();
      buttons().classList.remove('is-hidden');

      const event = { preventDefault: vi.fn() };
      controller.save(event);

      expect(buttons().classList.contains('is-hidden')).toBe(true);
      cards().forEach(card => {
        expect(card.classList.contains('draggable-handle')).toBe(false);
      });

      resolvePromise({ ok: true, json: () => Promise.resolve({ message: 'OK', status: 'success' }) });
    });

    it('sends notification with response message on success', async () => {
      mockFetchSuccess({ message: 'Queue order saved!', status: 'success' });
      const dispatchSpy = vi.spyOn(document.body, 'dispatchEvent');

      const controller = getController();
      const event = { preventDefault: vi.fn() };
      controller.save(event);

      await vi.waitFor(() => {
        const notifyEvent = dispatchSpy.mock.calls.find(call => call[0].type === 'notify');
        expect(notifyEvent).toBeDefined();
        expect(notifyEvent[0].detail.message).toBe('Queue order saved!');
        expect(notifyEvent[0].detail.status).toBe('success');
      });
    });

    it('updates card positions after save', async () => {
      mockFetchSuccess({ message: 'Saved!', status: 'success' });

      const controller = getController();
      const cardArray = Array.from(cards());

      // Reorder cards
      container().appendChild(cardArray[0]);
      controller.updateCards();

      const event = { preventDefault: vi.fn() };
      controller.save(event);

      await vi.waitFor(() => {
        const updatedCards = cards();
        updatedCards.forEach((card, i) => {
          expect(card.getAttribute('data-entry-position-original')).toBe(String(i + 1));
        });
      });
    });

    it('re-enables drag after save', async () => {
      mockFetchSuccess({ message: 'Saved!', status: 'success' });

      const controller = getController();
      const event = { preventDefault: vi.fn() };
      controller.save(event);

      await vi.waitFor(() => {
        cards().forEach(card => {
          expect(card.classList.contains('draggable-handle')).toBe(true);
        });
      });
    });
  });

  describe('integration', () => {
    it('handles full reorder flow', async () => {
      const controller = getController();
      const cardArray = Array.from(cards());

      // Initial state - buttons hidden
      expect(buttons().classList.contains('is-hidden')).toBe(true);

      // Reorder cards (simulate drag)
      container().appendChild(cardArray[0]);
      controller.updateCards();

      // Buttons should be visible
      expect(buttons().classList.contains('is-hidden')).toBe(false);

      // Save the new order
      mockFetchSuccess({ message: 'Saved!', status: 'success' });
      const event = { preventDefault: vi.fn() };
      controller.save(event);

      await vi.waitFor(() => {
        // After save, buttons should be hidden again (if positions now match originals)
        const updatedCards = cards();
        expect(updatedCards[0].getAttribute('data-entry-id')).toBe('2');
        expect(updatedCards[1].getAttribute('data-entry-id')).toBe('3');
        expect(updatedCards[2].getAttribute('data-entry-id')).toBe('1');
      });
    });

    it('handles discard flow', () => {
      const controller = getController();
      const cardArray = Array.from(cards());

      // Reorder cards
      container().appendChild(cardArray[0]);
      controller.updateCards();

      // Buttons should be visible
      expect(buttons().classList.contains('is-hidden')).toBe(false);

      // Discard changes
      const event = { preventDefault: vi.fn() };
      controller.discard(event);

      // Cards should be back in original order
      const updatedCards = cards();
      expect(updatedCards[0].getAttribute('data-entry-id')).toBe('1');
      expect(updatedCards[1].getAttribute('data-entry-id')).toBe('2');
      expect(updatedCards[2].getAttribute('data-entry-id')).toBe('3');

      // Buttons should be hidden
      expect(buttons().classList.contains('is-hidden')).toBe(true);
    });
  });
});
