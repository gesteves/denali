/* global L */
import { fetchStatus, fetchJson } from '../../lib/utils';
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
    if (!window.location.hash) {
      window.location.hash = '1/10.46/-66.96';
    }
    this.showLoadingSpinner();

    const southWest = L.latLng(-90, -180);
    const northEast = L.latLng(90, 180);
    const bounds = L.latLngBounds(southWest, northEast);
    const zoom = this.getZoom();
    const containerId = this.containerTarget.id;
    L.mapbox.accessToken = this.apiTokenValue;
    this.map = L.mapbox.map(containerId, null, { minZoom: zoom, maxZoom: 18, maxBounds: bounds }).addLayer(L.mapbox.styleLayer(this.mapStyleValue));

    fetch(this.markersUrlValue)
      .then(fetchStatus)
      .then(fetchJson)
      .then(geojson => this.loadMarkers(geojson))
      .catch(() => this.hideLoadingSpinner());
  }

  disconnect () {
    if (this.hash) {
      this.hash.remove();
      this.hash = null;
    }
    if (this.map) {
      this.map.remove();
      this.map = null;
    }
  }

  loadMarkers (geojson) {
    const icon = L.divIcon({
      className: 'map__marker map__marker--bloop',
      html: '&bull;',
      iconSize: [20, 20],
      iconAnchor: [10, 10]
    });

    const geoJsonLayer = L.geoJson(geojson, {
      pointToLayer: (feature, latlng) => {
        const marker = L.marker(latlng, { icon });
        marker.photoId = feature.properties.id;
        marker.bindPopup('', { closeButton: true, minWidth: 300 });
        marker.addOneTimeEventListener('popupopen', e => this.requestPopup(e));
        return marker;
      }
    });

    const clusterGroup = new L.MarkerClusterGroup({
      showCoverageOnHover: false,
      maxClusterRadius: 45,
      spiderfyDistanceMultiplier: 3,
      chunkedLoading: true,
      iconCreateFunction: this.setUpClusterIcon
    });
    clusterGroup.addLayers(geoJsonLayer.getLayers());

    this.hash = new L.hash(this.map);
    this.map.addLayer(clusterGroup);
    this.hideLoadingSpinner();
  }

  showLoadingSpinner () {
    this.spinnerTarget.style.display = 'block';
  }

  hideLoadingSpinner () {
    this.spinnerTarget.style.display = 'none';
  }

  getZoom () {
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

  requestPopup (e) {
    const marker = e.target;
    const url = this.photoUrlValue.replace(':id', marker.photoId);
    fetch(url)
      .then(fetchStatus)
      .then(fetchJson)
      .then(json => marker.setPopupContent(json.html))
      .catch(() => marker.setPopupContent('Failed to load photo.'));
  }

  setUpClusterIcon (cluster) {
    return L.divIcon({
      className: 'map__marker map__marker--cluster',
      html: cluster.getChildCount(),
      iconSize: [30, 30],
      iconAnchor: [15, 15]
    });
  }
}
