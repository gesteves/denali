//= require intersection-observer/intersection-observer
//= require ./vendors/loadcss
//= require ./vendors/cssrelpreload
//= require ./application/image_zoom
//= require ./application/lazy_load

if (navigator.serviceWorker) {
  navigator.serviceWorker.register('/service_worker.js', {
    scope: '/'
  });
}
