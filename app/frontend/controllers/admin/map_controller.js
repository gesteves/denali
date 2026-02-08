import mapboxgl from 'mapbox-gl';
import { Controller }             from '@hotwired/stimulus';

/**
 * Controls the Map view, setting up the map, the markers, and the popups.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['container', 'spinner'];
  static values = {
    mapStyle: String,
    apiToken: String,
    markersUrl: String,
    photoUrl: String
  }

  connect () {
    this.showLoadingSpinner();

    mapboxgl.accessToken = this.apiTokenValue;
    this.map = new mapboxgl.Map({
      container: this.containerTarget,
      style: this.mapStyleValue,
      center: [-98.57947729898336, 39.82834092754513],
      zoom: 1,
      minZoom: this.getMinZoom(),
      maxZoom: 18,
      hash: true
    });

    this.map.on('load', () => this.loadMarkers());
  }

  disconnect () {
    if (this.map) {
      this.map.remove();
      this.map = null;
    }
  }

  loadMarkers () {
    this.map.addSource('photos', {
      type: 'geojson',
      data: this.markersUrlValue,
      cluster: true,
      clusterRadius: 45
    });

    this.map.addLayer({
      id: 'clusters',
      type: 'circle',
      source: 'photos',
      filter: ['has', 'point_count'],
      paint: {
        'circle-color': '#3e8ed0',
        'circle-radius': 15,
        'circle-stroke-width': 2,
        'circle-stroke-color': '#2b74b1'
      }
    });

    this.map.addLayer({
      id: 'cluster-count',
      type: 'symbol',
      source: 'photos',
      filter: ['has', 'point_count'],
      layout: {
        'text-field': ['get', 'point_count_abbreviated'],
        'text-size': 10
      },
      paint: {
        'text-color': '#ffffff'
      }
    });

    this.map.addLayer({
      id: 'unclustered-point',
      type: 'circle',
      source: 'photos',
      filter: ['!', ['has', 'point_count']],
      paint: {
        'circle-color': '#3e8ed0',
        'circle-radius': 7,
        'circle-stroke-width': 1,
        'circle-stroke-color': '#2b74b1'
      }
    });

    this.map.on('click', 'clusters', (e) => {
      const features = this.map.queryRenderedFeatures(e.point, { layers: ['clusters'] });
      const clusterId = features[0].properties.cluster_id;
      this.map.getSource('photos').getClusterExpansionZoom(clusterId, (err, zoom) => {
        if (err) return;
        this.map.easeTo({ center: features[0].geometry.coordinates, zoom });
      });
    });

    this.map.on('click', 'unclustered-point', (e) => this.showPopup(e));

    this.map.on('mouseenter', 'clusters', () => {
      this.map.getCanvas().style.cursor = 'pointer';
    });
    this.map.on('mouseleave', 'clusters', () => {
      this.map.getCanvas().style.cursor = '';
    });
    this.map.on('mouseenter', 'unclustered-point', () => {
      this.map.getCanvas().style.cursor = 'pointer';
    });
    this.map.on('mouseleave', 'unclustered-point', () => {
      this.map.getCanvas().style.cursor = '';
    });

    this.hideLoadingSpinner();
  }

  async showPopup (e) {
    const coordinates = e.features[0].geometry.coordinates.slice();
    const photoId = e.features[0].properties.id;
    const url = this.photoUrlValue.replace(':id', photoId);

    const popup = new mapboxgl.Popup({ closeButton: true, minWidth: 300 })
      .setLngLat(coordinates)
      .setHTML('Loading…')
      .addTo(this.map);

    try {
      const response = await fetch(url);
      if (!response.ok) throw new Error(response.status);
      const json = await response.json();
      popup.setHTML(json.html);
    } catch {
      popup.setHTML('Failed to load photo.');
    }
  }

  showLoadingSpinner () {
    this.spinnerTarget.style.display = 'block';
  }

  hideLoadingSpinner () {
    this.spinnerTarget.style.display = 'none';
  }

  getMinZoom () {
    const height = document.documentElement.clientHeight;
    const width = document.documentElement.clientWidth;

    if ((width >= 2560) || (height >= 1440)) {
      return 4;
    } else if ((width >= 1920 ) || (height >= 1200)) {
      return 3;
    } else {
      return 2;
    }
  }
}
