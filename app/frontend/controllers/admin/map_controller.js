/* global L */
import { fetchStatus, fetchJson } from '../../lib/utils';
import { Controller }             from 'stimulus';

/**
 * Controls the Map view, setting up the map, the markers, and the popups.
 * TODO: This is kinda messy, you should clean this shit up.
 * TODO: It'd also be nice to switch to Google Maps.
 * @extends Controller
 */
export default class extends Controller {
  static targets = ['container', 'spinner'];
  static values = {
    style: String,
    apiToken: String,
    markersUrl: String
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
    let layer = L.mapbox.featureLayer();
    layer.on('layeradd', e => this.setUpMarker(e));
    layer.loadURL(this.markersUrlValue).on('ready', e => this.setUpMarkerClusters(e));
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

  setUpMarker (e) {
    const marker = e.layer;
    const feature = marker.feature;
    marker.photoId = feature.properties.id;
    marker.setIcon(L.divIcon({
      className: 'map__marker map__marker--bloop',
      html: '&bull;',
      iconSize: [20, 20],
      iconAnchor: [10, 10]
    }));
    e.target.bindPopup('', {
      closeButton: true,
      minWidth: 300
    });
    marker.addOneTimeEventListener('popupopen', e => this.requestPopup(e));
  }

  requestPopup (e) {
    const marker = e.target;
    fetch(`/admin/map/photo/${marker.photoId}.json`)
      .then(fetchStatus)
      .then(fetchJson)
      .then(json => marker.setPopupContent(json.html));
  }

  setUpMarkerClusters (e) {
    const clusterGroup = new L.MarkerClusterGroup({
      showCoverageOnHover: false,
      maxClusterRadius: 45,
      spiderfyDistanceMultiplier: 3,
      iconCreateFunction: this.setUpClusterIcon
    });
    e.target.eachLayer(layer => clusterGroup.addLayer(layer));

    this.hash = new L.hash(this.map);
    this.map.addLayer(clusterGroup);
    this.hideLoadingSpinner();
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
