//= require leaflet.markercluster/dist/leaflet.markercluster
//= require leaflet-hash/leaflet-hash

'use strict';
class Map {
  constructor (containerId, latitude, longitude, mapId) {
    if (document.getElementById(containerId) === null) {
      return;
    }

    this.loadingSpinner = document.querySelector('.js-loading');

    if (!window.location.hash) {
      window.location.hash = `1/${latitude}/${longitude}`;
    }

    this.showLoadingSpinner();

    let southWest = L.latLng(-90, -180),
        northEast = L.latLng(90, 180),
        bounds = L.latLngBounds(southWest, northEast),
        zoom = this.getZoom();

    L.mapbox.accessToken = window.mapboxToken;
    this.map = L.mapbox.map(containerId, mapId, { minZoom: zoom, maxZoom: 18, maxBounds: bounds });
    let layer = L.mapbox.featureLayer();
    layer.on('layeradd', e => this.setUpMarker(e));
    layer.loadURL('/map/photos.json').on('ready', e => this.setUpMarkerClusters(e));
  }

  showLoadingSpinner () {
    this.loadingSpinner.style.display = 'block';
  }

  hideLoadingSpinner () {
    this.loadingSpinner.style.display = 'none';
  }

  getZoom () {
    let height = document.documentElement.clientHeight,
        width = document.documentElement.clientWidth;

    if ((width >= 2560) || (height >= 1440)) {
      return 4;
    } else if ((width >= 1920 ) || (height >= 1200)) {
      return 3;
    } else {
      return 2;
    }
  }

  requestPopup (e) {
    let marker = e.target;
    let request = new XMLHttpRequest();
    request.open('GET', `/map/photo/${marker.photoId}.json`, true);
    request.onload = () => {
      if (request.status >= 200 && request.status < 400) {
        let response = JSON.parse(request.responseText);
        marker.setPopupContent(response.html);
      }
    };
    request.send();
  }

  trackPopupOpen (e) {
    let marker = e.target;
    if (typeof ga !== 'undefined') {
      ga('send', 'event', 'Map', 'Popup Open', marker.photoId);
    }
    if (typeof gtag !== 'undefined') {
      gtag('event', 'map_popup_open', { 'photo_id': marker.photoId });
    }
  }

  setUpMarker (e) {
    let marker = e.layer,
        feature = marker.feature;
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
    marker.addEventListener('popupopen', e => this.trackPopupOpen(e));
  }

  setUpClusterIcon (cluster) {
    return L.divIcon({
        className: 'map__marker map__marker--cluster',
        html: cluster.getChildCount(),
        iconSize: [30, 30],
        iconAnchor: [15, 15]
      }
    );
  }

  setUpMarkerClusters (e) {
    let clusterGroup = new L.MarkerClusterGroup({
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
}

if (document.readyState !== 'loading') {
  new Map('map', 10.46, -66.96, 'gesteves.ce0e3aae');
} else {
  document.addEventListener('DOMContentLoaded', () => new Map('map', 10.46, -66.96, 'gesteves.ce0e3aae'));
}
