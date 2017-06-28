//= require intersection-observer/intersection-observer
//= require fg-loadcss/src/loadCSS
//= require fg-loadcss/src/cssrelpreload
//= require ./application/image_zoom
//= require ./application/lazy_load

if (navigator.serviceWorker) {
  navigator.serviceWorker.register('/service_worker.js', {
    scope: '/'
  });
}
