import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';
import MapController from './map_controller';

describe('MapController', () => {
  let application;
  let element;
  let mockMap;
  let mockLayer;
  let mockClusterGroup;

  beforeEach(() => {
    global.fetch = vi.fn();

    // Reset mocks
    mockMap = {
      addLayer: vi.fn().mockReturnThis(),
      remove: vi.fn()
    };

    mockLayer = {
      on: vi.fn().mockReturnThis(),
      loadURL: vi.fn().mockReturnThis(),
      eachLayer: vi.fn()
    };

    mockClusterGroup = {
      addLayer: vi.fn()
    };

    // Reset location hash - use a mutable object
    const locationMock = {
      href: 'http://localhost:3000/',
      origin: 'http://localhost:3000',
      pathname: '/',
      search: '',
      hash: ''
    };
    Object.defineProperty(window, 'location', {
      value: locationMock,
      writable: true,
      configurable: true
    });

    // Mock Leaflet and mapbox
    class MockMarkerClusterGroup {
      constructor(options) {
        this.options = options;
        Object.assign(this, mockClusterGroup);
      }
    }

    global.L = {
      latLng: vi.fn((lat, lng) => ({ lat, lng })),
      latLngBounds: vi.fn((sw, ne) => ({ sw, ne })),
      divIcon: vi.fn(() => ({})),
      hash: vi.fn(function () { this.remove = vi.fn(); }),
      MarkerClusterGroup: MockMarkerClusterGroup,
      mapbox: {
        accessToken: null,
        map: vi.fn(() => mockMap),
        styleLayer: vi.fn(() => 'styleLayer'),
        featureLayer: vi.fn(() => mockLayer)
      }
    };

    document.body.innerHTML = `
      <div data-controller="map"
           data-map-map-style-value="mapbox://styles/test/style"
           data-map-api-token-value="test-api-token"
           data-map-markers-url-value="/admin/map/markers.geojson"
           data-map-photo-url-value="/admin/map/photo/:id.json">
        <div id="map-container" data-map-target="container"></div>
        <div data-map-target="spinner" style="display: none;"></div>
      </div>
    `;

    element = document.querySelector('[data-controller="map"]');
    application = Application.start();
    application.register('map', MapController);
  });

  afterEach(() => {
    application.stop();
    document.body.innerHTML = '';
    vi.clearAllMocks();
    delete global.L;
  });

  function getController() {
    return application.getControllerForElementAndIdentifier(element, 'map');
  }

  function spinnerTarget() {
    return element.querySelector('[data-map-target="spinner"]');
  }

  function mockFetchSuccess(data) {
    global.fetch.mockResolvedValueOnce({
      ok: true,
      json: () => Promise.resolve(data)
    });
  }

  function mockFetchFailure() {
    global.fetch.mockResolvedValueOnce({
      ok: false,
      status: 500
    });
  }

  describe('connect', () => {
    it('sets default hash if not present', () => {
      // The hash is set by the controller's connect method
      expect(window.location.hash).toContain('1/10.46/-66.96');
    });

    it('shows loading spinner on connect', () => {
      expect(spinnerTarget().style.display).toBe('block');
    });

    it('sets mapbox access token', () => {
      expect(L.mapbox.accessToken).toBe('test-api-token');
    });

    it('creates map with correct container', () => {
      expect(L.mapbox.map).toHaveBeenCalledWith(
        'map-container',
        null,
        expect.objectContaining({
          minZoom: expect.any(Number),
          maxZoom: 18
        })
      );
    });

    it('loads markers from URL', () => {
      expect(mockLayer.loadURL).toHaveBeenCalledWith('/admin/map/markers.geojson');
    });
  });

  describe('disconnect', () => {
    it('removes the map instance', () => {
      const controller = getController();
      // Simulate that setUpMarkerClusters has run to set this.hash
      controller.hash = { remove: vi.fn() };

      controller.disconnect();

      expect(mockMap.remove).toHaveBeenCalled();
      expect(controller.map).toBeNull();
    });

    it('removes the hash instance', () => {
      const controller = getController();
      const mockHashRemove = vi.fn();
      controller.hash = { remove: mockHashRemove };

      controller.disconnect();

      expect(mockHashRemove).toHaveBeenCalled();
      expect(controller.hash).toBeNull();
    });

    it('handles disconnect when hash is not set', () => {
      const controller = getController();
      controller.hash = null;

      expect(() => controller.disconnect()).not.toThrow();
    });

    it('handles disconnect when map is not set', () => {
      const controller = getController();
      controller.map = null;

      expect(() => controller.disconnect()).not.toThrow();
    });
  });

  describe('getZoom', () => {
    it('returns 4 for large screens (2560px+ width)', () => {
      Object.defineProperty(document.documentElement, 'clientWidth', { value: 2560, configurable: true });
      Object.defineProperty(document.documentElement, 'clientHeight', { value: 1080, configurable: true });

      const controller = getController();
      expect(controller.getZoom()).toBe(4);
    });

    it('returns 4 for large screens (1440px+ height)', () => {
      Object.defineProperty(document.documentElement, 'clientWidth', { value: 1920, configurable: true });
      Object.defineProperty(document.documentElement, 'clientHeight', { value: 1440, configurable: true });

      const controller = getController();
      expect(controller.getZoom()).toBe(4);
    });

    it('returns 3 for medium screens (1920px+ width)', () => {
      Object.defineProperty(document.documentElement, 'clientWidth', { value: 1920, configurable: true });
      Object.defineProperty(document.documentElement, 'clientHeight', { value: 1080, configurable: true });

      const controller = getController();
      expect(controller.getZoom()).toBe(3);
    });

    it('returns 3 for medium screens (1200px+ height)', () => {
      Object.defineProperty(document.documentElement, 'clientWidth', { value: 1600, configurable: true });
      Object.defineProperty(document.documentElement, 'clientHeight', { value: 1200, configurable: true });

      const controller = getController();
      expect(controller.getZoom()).toBe(3);
    });

    it('returns 2 for smaller screens', () => {
      Object.defineProperty(document.documentElement, 'clientWidth', { value: 1366, configurable: true });
      Object.defineProperty(document.documentElement, 'clientHeight', { value: 768, configurable: true });

      const controller = getController();
      expect(controller.getZoom()).toBe(2);
    });
  });

  describe('showLoadingSpinner', () => {
    it('sets spinner display to block', () => {
      const controller = getController();
      spinnerTarget().style.display = 'none';

      controller.showLoadingSpinner();

      expect(spinnerTarget().style.display).toBe('block');
    });
  });

  describe('hideLoadingSpinner', () => {
    it('sets spinner display to none', () => {
      const controller = getController();
      spinnerTarget().style.display = 'block';

      controller.hideLoadingSpinner();

      expect(spinnerTarget().style.display).toBe('none');
    });
  });

  describe('setUpMarker', () => {
    it('sets marker photoId from feature properties', () => {
      const controller = getController();
      const marker = {
        feature: { properties: { id: 42 } },
        setIcon: vi.fn(),
        addOneTimeEventListener: vi.fn()
      };
      const event = {
        layer: marker,
        target: { bindPopup: vi.fn() }
      };

      controller.setUpMarker(event);

      expect(marker.photoId).toBe(42);
    });

    it('sets marker icon with correct configuration', () => {
      const controller = getController();
      const marker = {
        feature: { properties: { id: 1 } },
        setIcon: vi.fn(),
        addOneTimeEventListener: vi.fn()
      };
      const event = {
        layer: marker,
        target: { bindPopup: vi.fn() }
      };

      controller.setUpMarker(event);

      expect(L.divIcon).toHaveBeenCalledWith({
        className: 'map__marker map__marker--bloop',
        html: '&bull;',
        iconSize: [20, 20],
        iconAnchor: [10, 10]
      });
      expect(marker.setIcon).toHaveBeenCalled();
    });

    it('binds popup to marker', () => {
      const controller = getController();
      const marker = {
        feature: { properties: { id: 1 } },
        setIcon: vi.fn(),
        addOneTimeEventListener: vi.fn()
      };
      const bindPopup = vi.fn();
      const event = {
        layer: marker,
        target: { bindPopup }
      };

      controller.setUpMarker(event);

      expect(bindPopup).toHaveBeenCalledWith('', {
        closeButton: true,
        minWidth: 300
      });
    });

    it('adds popupopen event listener', () => {
      const controller = getController();
      const marker = {
        feature: { properties: { id: 1 } },
        setIcon: vi.fn(),
        addOneTimeEventListener: vi.fn()
      };
      const event = {
        layer: marker,
        target: { bindPopup: vi.fn() }
      };

      controller.setUpMarker(event);

      expect(marker.addOneTimeEventListener).toHaveBeenCalledWith(
        'popupopen',
        expect.any(Function)
      );
    });
  });

  describe('requestPopup', () => {
    it('fetches popup content from the photo URL value', async () => {
      mockFetchSuccess({ html: '<div>Photo content</div>' });

      const controller = getController();
      const marker = {
        photoId: 42,
        setPopupContent: vi.fn()
      };
      const event = { target: marker };

      controller.requestPopup(event);

      await vi.waitFor(() => {
        expect(global.fetch).toHaveBeenCalledWith('/admin/map/photo/42.json');
      });
    });

    it('sets popup content on success', async () => {
      mockFetchSuccess({ html: '<div>Photo content</div>' });

      const controller = getController();
      const marker = {
        photoId: 42,
        setPopupContent: vi.fn()
      };
      const event = { target: marker };

      controller.requestPopup(event);

      await vi.waitFor(() => {
        expect(marker.setPopupContent).toHaveBeenCalledWith('<div>Photo content</div>');
      });
    });

    it('sets error message on fetch failure', async () => {
      mockFetchFailure();

      const controller = getController();
      const marker = {
        photoId: 42,
        setPopupContent: vi.fn()
      };
      const event = { target: marker };

      controller.requestPopup(event);

      await vi.waitFor(() => {
        expect(marker.setPopupContent).toHaveBeenCalledWith('Failed to load photo.');
      });
    });

    it('sets error message on network error', async () => {
      global.fetch.mockRejectedValueOnce(new Error('Network error'));

      const controller = getController();
      const marker = {
        photoId: 42,
        setPopupContent: vi.fn()
      };
      const event = { target: marker };

      controller.requestPopup(event);

      await vi.waitFor(() => {
        expect(marker.setPopupContent).toHaveBeenCalledWith('Failed to load photo.');
      });
    });
  });

  describe('setUpMarkerClusters', () => {
    it('creates MarkerClusterGroup with correct options', () => {
      const controller = getController();
      const event = {
        target: { eachLayer: vi.fn() }
      };

      controller.setUpMarkerClusters(event);

      // Verify that the cluster was created by checking that it was added to the map
      expect(mockMap.addLayer).toHaveBeenCalled();
    });

    it('adds layers to cluster group', () => {
      const controller = getController();
      const mockEachLayer = vi.fn((callback) => {
        callback({ id: 'layer1' });
        callback({ id: 'layer2' });
      });
      const event = {
        target: { eachLayer: mockEachLayer }
      };

      controller.setUpMarkerClusters(event);

      expect(mockClusterGroup.addLayer).toHaveBeenCalledTimes(2);
    });

    it('adds cluster group to map', () => {
      const controller = getController();
      const event = {
        target: { eachLayer: vi.fn() }
      };

      controller.setUpMarkerClusters(event);

      // Verify the second addLayer call (first is styleLayer)
      expect(mockMap.addLayer).toHaveBeenCalledTimes(2);
      const secondCall = mockMap.addLayer.mock.calls[1][0];
      expect(secondCall).toHaveProperty('addLayer');
    });

    it('hides loading spinner', () => {
      const controller = getController();
      spinnerTarget().style.display = 'block';
      const event = {
        target: { eachLayer: vi.fn() }
      };

      controller.setUpMarkerClusters(event);

      expect(spinnerTarget().style.display).toBe('none');
    });

    it('creates hash for URL tracking', () => {
      const controller = getController();
      const event = {
        target: { eachLayer: vi.fn() }
      };

      controller.setUpMarkerClusters(event);

      expect(L.hash).toHaveBeenCalledWith(mockMap);
    });
  });

  describe('setUpClusterIcon', () => {
    it('creates divIcon with cluster count', () => {
      const controller = getController();
      const cluster = {
        getChildCount: vi.fn(() => 15)
      };

      controller.setUpClusterIcon(cluster);

      expect(L.divIcon).toHaveBeenCalledWith({
        className: 'map__marker map__marker--cluster',
        html: 15,
        iconSize: [30, 30],
        iconAnchor: [15, 15]
      });
    });
  });
});
