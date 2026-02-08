import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { Application } from '@hotwired/stimulus';
import MapController from './map_controller';

let mockMap;
let mockPopup;
let mockSource;

vi.mock('mapbox-gl', () => {
  const actual = {
    accessToken: null,
    Map: vi.fn(function (options) {
      mockMap._options = options;
      return mockMap;
    }),
    Popup: vi.fn(function (options) {
      mockPopup._options = options;
      return mockPopup;
    })
  };
  return { default: actual };
});

describe('MapController', () => {
  let application;
  let element;

  beforeEach(async () => {
    const mapboxgl = (await import('mapbox-gl')).default;

    mockSource = {
      getClusterExpansionZoom: vi.fn()
    };

    mockMap = {
      _options: null,
      on: vi.fn(),
      addSource: vi.fn(),
      addLayer: vi.fn(),
      getSource: vi.fn(() => mockSource),
      getCanvas: vi.fn(() => ({ style: {} })),
      queryRenderedFeatures: vi.fn(),
      easeTo: vi.fn(),
      remove: vi.fn()
    };

    mockPopup = {
      _options: null,
      setLngLat: vi.fn().mockReturnThis(),
      setHTML: vi.fn().mockReturnThis(),
      addTo: vi.fn().mockReturnThis()
    };

    mapboxgl.accessToken = null;
    mapboxgl.Map.mockClear();
    mapboxgl.Popup.mockClear();

    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ html: '<div>Photo</div>' })
    });

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
  });

  function getController () {
    return application.getControllerForElementAndIdentifier(element, 'map');
  }

  function spinnerTarget () {
    return element.querySelector('[data-map-target="spinner"]');
  }

  function triggerMapLoad () {
    const loadCallback = mockMap.on.mock.calls.find(c => c[0] === 'load')[1];
    loadCallback();
  }

  describe('connect', () => {
    it('sets mapbox access token', async () => {
      const mapboxgl = (await import('mapbox-gl')).default;
      expect(mapboxgl.accessToken).toBe('test-api-token');
    });

    it('creates map with correct options', async () => {
      const mapboxgl = (await import('mapbox-gl')).default;
      expect(mapboxgl.Map).toHaveBeenCalledTimes(1);

      const options = mockMap._options;
      expect(options.container).toBe(element.querySelector('#map-container'));
      expect(options.style).toBe('mapbox://styles/test/style');
      expect(options.center).toEqual([-98.57947729898336, 39.82834092754513]);
      expect(options.zoom).toBe(1);
      expect(options.minZoom).toEqual(expect.any(Number));
      expect(options.maxZoom).toBe(18);
      expect(options.hash).toBe(true);
    });

    it('registers load listener', () => {
      const loadCall = mockMap.on.mock.calls.find(c => c[0] === 'load');
      expect(loadCall).toBeTruthy();
      expect(typeof loadCall[1]).toBe('function');
    });

    it('shows loading spinner on connect', () => {
      expect(spinnerTarget().style.display).toBe('block');
    });
  });

  describe('disconnect', () => {
    it('removes the map instance', () => {
      const controller = getController();
      controller.disconnect();

      expect(mockMap.remove).toHaveBeenCalled();
      expect(controller.map).toBeNull();
    });

    it('handles disconnect when map is not set', () => {
      const controller = getController();
      controller.map = null;

      expect(() => controller.disconnect()).not.toThrow();
    });
  });

  describe('loadMarkers', () => {
    beforeEach(() => {
      triggerMapLoad();
    });

    it('adds GeoJSON source with clustering', () => {
      expect(mockMap.addSource).toHaveBeenCalledWith('photos', {
        type: 'geojson',
        data: '/admin/map/markers.geojson',
        cluster: true,
        clusterRadius: 45
      });
    });

    it('adds clusters circle layer', () => {
      expect(mockMap.addLayer).toHaveBeenCalledWith(
        expect.objectContaining({
          id: 'clusters',
          type: 'circle',
          source: 'photos',
          filter: ['has', 'point_count']
        })
      );
    });

    it('adds cluster-count symbol layer', () => {
      expect(mockMap.addLayer).toHaveBeenCalledWith(
        expect.objectContaining({
          id: 'cluster-count',
          type: 'symbol',
          source: 'photos',
          filter: ['has', 'point_count']
        })
      );
    });

    it('adds unclustered-point circle layer', () => {
      expect(mockMap.addLayer).toHaveBeenCalledWith(
        expect.objectContaining({
          id: 'unclustered-point',
          type: 'circle',
          source: 'photos',
          filter: ['!', ['has', 'point_count']]
        })
      );
    });

    it('adds three layers total', () => {
      expect(mockMap.addLayer).toHaveBeenCalledTimes(3);
    });

    it('registers click handler for clusters', () => {
      const clusterClick = mockMap.on.mock.calls.find(
        c => c[0] === 'click' && c[1] === 'clusters'
      );
      expect(clusterClick).toBeTruthy();
    });

    it('registers click handler for unclustered points', () => {
      const pointClick = mockMap.on.mock.calls.find(
        c => c[0] === 'click' && c[1] === 'unclustered-point'
      );
      expect(pointClick).toBeTruthy();
    });

    it('registers cursor handlers for clusters and points', () => {
      const mouseenterClusters = mockMap.on.mock.calls.find(
        c => c[0] === 'mouseenter' && c[1] === 'clusters'
      );
      const mouseleaveClusters = mockMap.on.mock.calls.find(
        c => c[0] === 'mouseleave' && c[1] === 'clusters'
      );
      const mouseenterPoints = mockMap.on.mock.calls.find(
        c => c[0] === 'mouseenter' && c[1] === 'unclustered-point'
      );
      const mouseleavePoints = mockMap.on.mock.calls.find(
        c => c[0] === 'mouseleave' && c[1] === 'unclustered-point'
      );

      expect(mouseenterClusters).toBeTruthy();
      expect(mouseleaveClusters).toBeTruthy();
      expect(mouseenterPoints).toBeTruthy();
      expect(mouseleavePoints).toBeTruthy();
    });

    it('hides loading spinner', () => {
      expect(spinnerTarget().style.display).toBe('none');
    });
  });

  describe('cluster click', () => {
    it('zooms to cluster expansion zoom on click', () => {
      triggerMapLoad();

      const clusterClickCall = mockMap.on.mock.calls.find(
        c => c[0] === 'click' && c[1] === 'clusters'
      );
      const handler = clusterClickCall[2];

      const event = { point: { x: 100, y: 100 } };
      const feature = {
        properties: { cluster_id: 42 },
        geometry: { coordinates: [-73.98, 40.75] }
      };
      mockMap.queryRenderedFeatures.mockReturnValue([feature]);

      handler(event);

      expect(mockMap.queryRenderedFeatures).toHaveBeenCalledWith(
        event.point, { layers: ['clusters'] }
      );
      expect(mockSource.getClusterExpansionZoom).toHaveBeenCalledWith(42, expect.any(Function));

      // Simulate callback
      const zoomCallback = mockSource.getClusterExpansionZoom.mock.calls[0][1];
      zoomCallback(null, 5);

      expect(mockMap.easeTo).toHaveBeenCalledWith({
        center: [-73.98, 40.75],
        zoom: 5
      });
    });

    it('does not zoom on cluster expansion error', () => {
      triggerMapLoad();

      const clusterClickCall = mockMap.on.mock.calls.find(
        c => c[0] === 'click' && c[1] === 'clusters'
      );
      const handler = clusterClickCall[2];

      const event = { point: { x: 100, y: 100 } };
      const feature = {
        properties: { cluster_id: 42 },
        geometry: { coordinates: [-73.98, 40.75] }
      };
      mockMap.queryRenderedFeatures.mockReturnValue([feature]);

      handler(event);

      const zoomCallback = mockSource.getClusterExpansionZoom.mock.calls[0][1];
      zoomCallback(new Error('fail'));

      expect(mockMap.easeTo).not.toHaveBeenCalled();
    });
  });

  describe('showPopup', () => {
    it('creates popup with coordinates and loading text', async () => {
      const mapboxgl = (await import('mapbox-gl')).default;
      triggerMapLoad();

      const pointClickCall = mockMap.on.mock.calls.find(
        c => c[0] === 'click' && c[1] === 'unclustered-point'
      );
      const handler = pointClickCall[2];

      handler({
        features: [{
          geometry: { coordinates: [-73.98, 40.75] },
          properties: { id: 42 }
        }]
      });

      expect(mapboxgl.Popup).toHaveBeenCalledWith({ closeButton: true, minWidth: 300 });
      expect(mockPopup.setLngLat).toHaveBeenCalledWith([-73.98, 40.75]);
      expect(mockPopup.setHTML).toHaveBeenCalledWith('Loading…');
      expect(mockPopup.addTo).toHaveBeenCalledWith(mockMap);
    });

    it('fetches photo content and updates popup', async () => {
      triggerMapLoad();

      const pointClickCall = mockMap.on.mock.calls.find(
        c => c[0] === 'click' && c[1] === 'unclustered-point'
      );
      const handler = pointClickCall[2];

      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ html: '<div>Photo content</div>' })
      });

      handler({
        features: [{
          geometry: { coordinates: [-73.98, 40.75] },
          properties: { id: 42 }
        }]
      });

      expect(global.fetch).toHaveBeenCalledWith('/admin/map/photo/42.json');

      await vi.waitFor(() => {
        expect(mockPopup.setHTML).toHaveBeenCalledWith('<div>Photo content</div>');
      });
    });

    it('shows error message on fetch failure', async () => {
      triggerMapLoad();

      const pointClickCall = mockMap.on.mock.calls.find(
        c => c[0] === 'click' && c[1] === 'unclustered-point'
      );
      const handler = pointClickCall[2];

      global.fetch.mockResolvedValueOnce({
        ok: false,
        status: 500
      });

      handler({
        features: [{
          geometry: { coordinates: [-73.98, 40.75] },
          properties: { id: 42 }
        }]
      });

      await vi.waitFor(() => {
        expect(mockPopup.setHTML).toHaveBeenCalledWith('Failed to load photo.');
      });
    });

    it('shows error message on network error', async () => {
      triggerMapLoad();

      const pointClickCall = mockMap.on.mock.calls.find(
        c => c[0] === 'click' && c[1] === 'unclustered-point'
      );
      const handler = pointClickCall[2];

      global.fetch.mockRejectedValueOnce(new Error('Network error'));

      handler({
        features: [{
          geometry: { coordinates: [-73.98, 40.75] },
          properties: { id: 42 }
        }]
      });

      await vi.waitFor(() => {
        expect(mockPopup.setHTML).toHaveBeenCalledWith('Failed to load photo.');
      });
    });
  });

  describe('cursor handlers', () => {
    it('sets pointer cursor on mouseenter clusters', () => {
      triggerMapLoad();

      const canvasStyle = {};
      mockMap.getCanvas.mockReturnValue({ style: canvasStyle });

      const mouseenterCall = mockMap.on.mock.calls.find(
        c => c[0] === 'mouseenter' && c[1] === 'clusters'
      );
      mouseenterCall[2]();

      expect(canvasStyle.cursor).toBe('pointer');
    });

    it('clears cursor on mouseleave clusters', () => {
      triggerMapLoad();

      const canvasStyle = { cursor: 'pointer' };
      mockMap.getCanvas.mockReturnValue({ style: canvasStyle });

      const mouseleaveCall = mockMap.on.mock.calls.find(
        c => c[0] === 'mouseleave' && c[1] === 'clusters'
      );
      mouseleaveCall[2]();

      expect(canvasStyle.cursor).toBe('');
    });
  });

  describe('getMinZoom', () => {
    it('returns 4 for large screens (2560px+ width)', () => {
      Object.defineProperty(document.documentElement, 'clientWidth', { value: 2560, configurable: true });
      Object.defineProperty(document.documentElement, 'clientHeight', { value: 1080, configurable: true });

      const controller = getController();
      expect(controller.getMinZoom()).toBe(4);
    });

    it('returns 4 for large screens (1440px+ height)', () => {
      Object.defineProperty(document.documentElement, 'clientWidth', { value: 1920, configurable: true });
      Object.defineProperty(document.documentElement, 'clientHeight', { value: 1440, configurable: true });

      const controller = getController();
      expect(controller.getMinZoom()).toBe(4);
    });

    it('returns 3 for medium screens (1920px+ width)', () => {
      Object.defineProperty(document.documentElement, 'clientWidth', { value: 1920, configurable: true });
      Object.defineProperty(document.documentElement, 'clientHeight', { value: 1080, configurable: true });

      const controller = getController();
      expect(controller.getMinZoom()).toBe(3);
    });

    it('returns 3 for medium screens (1200px+ height)', () => {
      Object.defineProperty(document.documentElement, 'clientWidth', { value: 1600, configurable: true });
      Object.defineProperty(document.documentElement, 'clientHeight', { value: 1200, configurable: true });

      const controller = getController();
      expect(controller.getMinZoom()).toBe(3);
    });

    it('returns 2 for smaller screens', () => {
      Object.defineProperty(document.documentElement, 'clientWidth', { value: 1366, configurable: true });
      Object.defineProperty(document.documentElement, 'clientHeight', { value: 768, configurable: true });

      const controller = getController();
      expect(controller.getMinZoom()).toBe(2);
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
});
