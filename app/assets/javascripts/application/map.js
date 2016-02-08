var Denali = Denali || {};

Denali.Map = (function () {
  'use strict';

  var opts = {
    map_container_id  : 'map',
    use_geolocation   : false,
    default_latitude  : 10.4383493,
    default_longitude : -66.8447572
  };

  var map,
      loading,
      show_bar = true;

  var init = function () {
    if (document.getElementById(opts.map_container_id) === null) {
      return;
    }
    loading = document.querySelector('.js-loading');
    loadMapbox();
  };

  var getLocation = function () {
    if ('geolocation' in navigator && opts.use_geolocation) {
      navigator.geolocation.getCurrentPosition(function (position) {
        initMap(position.coords.latitude, position.coords.longitude);
      }, function () {
        initMap(opts.default_latitude, opts.default_longitude);
      });
    } else {
      initMap(opts.default_latitude, opts.default_longitude);
    }
  };

  var loadMapbox = function () {
    loadJS('https://api.tiles.mapbox.com/mapbox.js/v2.3.0/mapbox.js', function () {
      loadMarkerCluster();
    });
    loadCSS('https://api.tiles.mapbox.com/mapbox.js/v2.3.0/mapbox.css');
  };

  var loadMarkerCluster = function () {
    loadJS('https://api.mapbox.com/mapbox.js/plugins/leaflet-markercluster/v0.4.0/leaflet.markercluster.js', function () {
      getLocation();
    });
    loadCSS('https://api.mapbox.com/mapbox.js/plugins/leaflet-markercluster/v0.4.0/MarkerCluster.css');
    loadCSS('https://api.tiles.mapbox.com/mapbox.js/plugins/leaflet-markercluster/v0.4.0/MarkerCluster.Default.css');
  };

  var showLoadingSpinner = function () {
    if (show_bar) {
      loading.style.display = 'block';
    }
  };

  var hideLoadingSpinner = function () {
    loading.style.display = 'none';
  };

  var initMap = function (latitude, longitude) {
    setTimeout(showLoadingSpinner, 500);
    L.mapbox.accessToken = 'pk.eyJ1IjoiZ2VzdGV2ZXMiLCJhIjoiY2lrY3EyeDA3MG03Y3Y5a3V6d3MwNHR3cSJ9.qG9UBVJvti71fNvW5iKONA';
    map = L.mapbox.map(opts.map_container_id, 'gesteves.ce0e3aae', { minZoom: 2, maxZoom: 18 }).setView([latitude, longitude], 2);

    var layer = L.mapbox.featureLayer();

    layer.on('layeradd', function(e) {
      var marker = e.layer,
          feature = marker.feature;
      var content = feature.properties.description;
      marker.setIcon(L.divIcon({
          className: 'map__marker map__marker--point',
          html: '&bull;',
          iconSize: [10, 10],
          iconAnchor: [5, 5]
        }));
      marker.bindPopup(content, {
        closeButton: true,
        minWidth: 319
      });
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
      map.addLayer(cluster_group);
      show_bar = false;
      hideLoadingSpinner();
    });
  };

  return {
    init : init,
  };
})();
