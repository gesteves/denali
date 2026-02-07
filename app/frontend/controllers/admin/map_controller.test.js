import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';
import MapController from './map_controller';

const EMPTY_GEOJSON = { type: 'FeatureCollection', features: [] };

const SAMPLE_GEOJSON = {
  type: 'FeatureCollection',
  features: [
    { type: 'Feature', geometry: { type: 'Point', coordinates: [-73.98, 40.75] }, properties: { id: 1 } },
    { type: 'Feature', geometry: { type: 'Point', coordinates: [-118.24, 34.05] }, properties: { id: 2 } }
  ]
};

describe('MapController', () => {
  let application;
  let element;
  let mockMap;
  let mockClusterGroup;

  beforeEach(() => {
    // Default fetch returns empty GeoJSON so connect() completes cleanly
    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve(EMPTY_GEOJSON)
    });

    mockMap = {
      addLayer: vi.fn().mockReturnThis(),
      remove: vi.fn()
    };

    mockClusterGroup = {
      addLayer: vi.fn(),
      addLayers: vi.fn()
    };

    // Reset location hash
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
      marker: vi.fn(() => ({
        photoId: null,
        bindPopup: vi.fn(),
        addOneTimeEventListener: vi.fn()
      })),
      geoJson: vi.fn((geojson, options) => {
        const layers = (geojson.features || []).map(feature => {
          const coords = feature.geometry.coordinates;
          const latlng = { lat: coords[1], lng: coords[0] };
          return options.pointToLayer(feature, latlng);
        });
        return { getLayers: () => layers };
      }),
      hash: vi.fn(function () { this.remove = vi.fn(); }),
      MarkerClusterGroup: MockMarkerClusterGroup,
      mapbox: {
        accessToken: null,
        map: vi.fn(() => mockMap),
        styleLayer: vi.fn(() => 'styleLayer')
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

    it('fetches markers from URL', () => {
      expect(global.fetch).toHaveBeenCalledWith('/admin/map/markers.geojson');
    });

    it('hides spinner on fetch failure', async () => {
      // Reset and set up a fresh controller with a failing fetch
      application.stop();
      document.body.innerHTML = '';
      vi.clearAllMocks();

      global.fetch = vi.fn().mockResolvedValue({ ok: false, status: 500 });

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

      const spinner = element.querySelector('[data-map-target="spinner"]');
      await vi.waitFor(() => {
        expect(spinner.style.display).toBe('none');
      });
    });
  });

  describe('disconnect', () => {
    it('removes the map instance', () => {
      const controller = getController();
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

  describe('loadMarkers', () => {
    it('creates a shared marker icon', () => {
      const controller = getController();
      controller.loadMarkers(SAMPLE_GEOJSON);

      expect(L.divIcon).toHaveBeenCalledWith({
        className: 'map__marker map__marker--bloop',
        html: '&bull;',
        iconSize: [20, 20],
        iconAnchor: [10, 10]
      });
    });

    it('parses GeoJSON with pointToLayer', () => {
      const controller = getController();
      controller.loadMarkers(SAMPLE_GEOJSON);

      expect(L.geoJson).toHaveBeenCalledWith(
        SAMPLE_GEOJSON,
        expect.objectContaining({ pointToLayer: expect.any(Function) })
      );
    });

    it('creates a marker for each feature', () => {
      const controller = getController();
      controller.loadMarkers(SAMPLE_GEOJSON);

      expect(L.marker).toHaveBeenCalledTimes(2);
    });

    it('sets photoId on each marker', () => {
      const markers = [];
      L.marker = vi.fn(() => {
        const m = { photoId: null, bindPopup: vi.fn(), addOneTimeEventListener: vi.fn() };
        markers.push(m);
        return m;
      });

      const controller = getController();
      controller.loadMarkers(SAMPLE_GEOJSON);

      expect(markers[0].photoId).toBe(1);
      expect(markers[1].photoId).toBe(2);
    });

    it('binds popup to each marker', () => {
      const markers = [];
      L.marker = vi.fn(() => {
        const m = { photoId: null, bindPopup: vi.fn(), addOneTimeEventListener: vi.fn() };
        markers.push(m);
        return m;
      });

      const controller = getController();
      controller.loadMarkers(SAMPLE_GEOJSON);

      markers.forEach(m => {
        expect(m.bindPopup).toHaveBeenCalledWith('', { closeButton: true, minWidth: 300 });
      });
    });

    it('adds popupopen listener to each marker', () => {
      const markers = [];
      L.marker = vi.fn(() => {
        const m = { photoId: null, bindPopup: vi.fn(), addOneTimeEventListener: vi.fn() };
        markers.push(m);
        return m;
      });

      const controller = getController();
      controller.loadMarkers(SAMPLE_GEOJSON);

      markers.forEach(m => {
        expect(m.addOneTimeEventListener).toHaveBeenCalledWith('popupopen', expect.any(Function));
      });
    });

    it('bulk-adds markers to cluster group via addLayers', () => {
      const controller = getController();
      controller.loadMarkers(SAMPLE_GEOJSON);

      expect(mockClusterGroup.addLayers).toHaveBeenCalledTimes(1);
      expect(mockClusterGroup.addLayers).toHaveBeenCalledWith(expect.any(Array));
      expect(mockClusterGroup.addLayers.mock.calls[0][0]).toHaveLength(2);
    });

    it('enables chunkedLoading on the cluster group', () => {
      const controller = getController();
      controller.loadMarkers(SAMPLE_GEOJSON);

      const clusterGroupInstance = mockMap.addLayer.mock.calls[1][0];
      expect(clusterGroupInstance.options.chunkedLoading).toBe(true);
    });

    it('adds cluster group to map', () => {
      const controller = getController();
      controller.loadMarkers(SAMPLE_GEOJSON);

      // Second addLayer call (first is styleLayer from connect)
      expect(mockMap.addLayer).toHaveBeenCalledTimes(2);
    });

    it('creates hash for URL tracking', () => {
      const controller = getController();
      controller.loadMarkers(SAMPLE_GEOJSON);

      expect(L.hash).toHaveBeenCalledWith(mockMap);
    });

    it('hides loading spinner', () => {
      const controller = getController();
      spinnerTarget().style.display = 'block';
      controller.loadMarkers(SAMPLE_GEOJSON);

      expect(spinnerTarget().style.display).toBe('none');
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
