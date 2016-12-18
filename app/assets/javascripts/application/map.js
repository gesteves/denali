//= require ../vendors/mapbox
//= require ../vendors/leaflet.markercluster
//= require ../vendors/leaflet.hash

var Denali = Denali || {};

Denali.Map = (function () {
  'use strict';

  var opts = {
    map_container_id  : 'map',
    default_latitude  : 38.8899389,
    default_longitude : -77.0112392
  };

  var map,
      loading,
      hash,
      show_bar = true;

  var init = function () {
    if (document.getElementById(opts.map_container_id) === null) {
      return;
    }
    loading = document.querySelector('.js-loading');
    initMap(opts.default_latitude, opts.default_longitude);
  };

  var showLoadingSpinner = function () {
    if (show_bar) {
      loading.style.display = 'block';
    }
  };

  var hideLoadingSpinner = function () {
    loading.style.display = 'none';
  };

  var getZoom = function () {
    var height = window.innerHeight,
        width = window.innerWidth;

    if ((width >= 2560) || (height >= 1440)) {
      return 4;
    } else if ((width >= 1920 ) || (height >= 1200)) {
      return 3;
    } else {
      return 2;
    }
  };

  var initMap = function () {
    setTimeout(showLoadingSpinner, 500);
    var south_west = L.latLng(-90, -180),
        north_east = L.latLng(90, 180),
        bounds = L.latLngBounds(south_west, north_east),
        zoom = getZoom();
    L.mapbox.accessToken = 'pk.eyJ1IjoiZ2VzdGV2ZXMiLCJhIjoiY2lrY3EyeDA3MG03Y3Y5a3V6d3MwNHR3cSJ9.qG9UBVJvti71fNvW5iKONA';
    map = L.mapbox.map(opts.map_container_id, 'gesteves.ce0e3aae', { minZoom: zoom, maxZoom: 18, maxBounds: bounds });

    var layer = L.mapbox.featureLayer();

    layer.on('layeradd', function(e) {
      var marker = e.layer,
          feature = marker.feature;
      var photo_id = feature.properties.id;
      marker.setIcon(L.divIcon({
          className: 'map__marker map__marker--point',
          html: '&bull;',
          iconSize: [10, 10],
          iconAnchor: [5, 5]
        }));
      this.bindPopup('', {
        closeButton: true,
        minWidth: 300
      });
      marker.on('popupopen', function () {
        var marker = this;
        var request = new XMLHttpRequest();
        request.open('GET', '/map/photo/' + photo_id + '.json', true);
        request.onload = function() {
          if (request.status >= 200 && request.status < 400) {
            var response = JSON.parse(request.responseText);
            marker.setPopupContent(response.html);
            marker.off('popupopen');
          }
        };
        request.send();
      });
    });
    layer.on('ready', function() {
      map.fitBounds(layer.getBounds().pad(0.01));
    });
    layer.loadURL('/map/photos.json').on('ready', function (e) {
      var cluster_group = new L.MarkerClusterGroup({
        showCoverageOnHover: false,
        maxClusterRadius: 30,
        spiderfyDistanceMultiplier: 3,
        iconCreateFunction: function (cluster) {
          return L.divIcon({
              className: 'map__marker map__marker--cluster',
              html: cluster.getChildCount(),
              iconSize: cluster.getChildCount() > 99 ? [30, 30] : [20, 20],
              iconAnchor: cluster.getChildCount() > 99 ? [15, 15] : [10, 10]
            }
          );
        }
      });
      e.target.eachLayer(function (layer) {
        cluster_group.addLayer(layer);
      });
      hash = new L.hash(map);
      map.addLayer(cluster_group);
      show_bar = false;
      hideLoadingSpinner();
    });
  };

  return {
    init : init
  };
})();

if (document.readyState !== 'loading') {
  Denali.Map.init();
} else {
  document.addEventListener('DOMContentLoaded', Denali.Map.init);
}
