var Denali = Denali || {};

Denali.Map = (function () {
  'use strict';

  var opts = {
    map_container_id  : 'map',
    use_geolocation   : false,
    default_latitude  : 10.4383493,
    default_longitude : -66.8447572
  };

  var map;

  var init = function () {
    if (document.getElementById(opts.map_container_id) === null) {
      return;
    }
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
      getLocation();
    };
    styles1.href = 'https://api.mapbox.com/mapbox.js/plugins/leaflet-markercluster/v0.4.0/MarkerCluster.css';
    styles1.rel = 'stylesheet';
    styles2.href = 'https://api.tiles.mapbox.com/mapbox.js/plugins/leaflet-markercluster/v0.4.0/MarkerCluster.Default.css';
    styles2.rel = 'stylesheet';
    head.appendChild(script);
    head.appendChild(styles1);
    head.appendChild(styles2);
  };

  var initMap = function (latitude, longitude) {
    L.mapbox.accessToken = 'pk.eyJ1IjoiZ2VzdGV2ZXMiLCJhIjoiY2lqN3RqcXVtMDAwZ3VtbHhpNGZoaWU3ZSJ9.4r3ypzJwvsZM5loCLETnFQ';
    map = L.mapbox.map(opts.map_container_id, 'gesteves.ce0e3aae').setView([latitude, longitude], 2);

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
        closeButton: false,
        minWidth: 319
      });
    });

    layer.loadURL('/map/photos.json').on('ready', function (e) {
      var cluster_group = new L.MarkerClusterGroup({
        showCoverageOnHover: false,
        maxClusterRadius: 50,
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
    });
  };

  return {
    init : init,
  };
})();
