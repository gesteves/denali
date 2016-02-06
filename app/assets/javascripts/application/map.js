var Denali = Denali || {};

Denali.Map = (function () {
  'use strict';

  var opts = {
    map_container_id : 'map'
  };

  var map;

  var init = function () {
    if (document.getElementById(opts.map_container_id) === null) {
      return;
    }
    loadMapbox();
  };

  var loadMapbox = function () {
    var head = document.getElementsByTagName('head')[0];
    var script = document.createElement('script');
    var styles = document.createElement('link');
    script.src = 'https://api.tiles.mapbox.com/mapbox.js/v2.3.0/mapbox.js';
    script.async = 'true';
    script.onload = function () {
      loadMarkerCluster();
    };
    styles.href = 'https://api.tiles.mapbox.com/mapbox.js/v2.3.0/mapbox.css';
    styles.rel = 'stylesheet';
    head.appendChild(script);
    head.appendChild(styles);
  };

  var loadMarkerCluster = function () {
    var head = document.getElementsByTagName('head')[0];
    var script = document.createElement('script');
    var styles1 = document.createElement('link');
    var styles2 = document.createElement('link');
    script.src = 'https://api.mapbox.com/mapbox.js/plugins/leaflet-markercluster/v0.4.0/leaflet.markercluster.js';
    script.async = 'true';
    script.onload = function () {
      initMap();
    };
    styles1.href = 'https://api.mapbox.com/mapbox.js/plugins/leaflet-markercluster/v0.4.0/MarkerCluster.css';
    styles1.rel = 'stylesheet';
    styles2.href = 'https://api.tiles.mapbox.com/mapbox.js/plugins/leaflet-markercluster/v0.4.0/MarkerCluster.Default.css';
    styles2.rel = 'stylesheet';
    head.appendChild(script);
    head.appendChild(styles1);
    head.appendChild(styles2);
  };

  var initMap = function () {
    L.mapbox.accessToken = 'pk.eyJ1IjoiZ2VzdGV2ZXMiLCJhIjoiY2lqN3RqcXVtMDAwZ3VtbHhpNGZoaWU3ZSJ9.4r3ypzJwvsZM5loCLETnFQ';
    map = L.mapbox.map(opts.map_container_id, 'mapbox.emerald').setView([38.8899389, -77.0112392], 2);

    var layer = L.mapbox.featureLayer();

    layer.loadURL('/map/photos.json').on('ready', function (e) {
      var cluster_group = new L.MarkerClusterGroup({
        showCoverageOnHover: false,
        maxClusterRadius: 50
      });
      e.target.eachLayer(function (layer) {
        console.log(layer);
        cluster_group.addLayer(layer);
      });
      map.addLayer(cluster_group);
    });
  };

  return {
    init : init,
  };
})();
