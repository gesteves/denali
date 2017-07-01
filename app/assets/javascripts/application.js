//= require fg-loadcss/src/loadCSS
//= require fg-loadcss/src/cssrelpreload

if (navigator.serviceWorker) {
  navigator.serviceWorker.register('/service_worker.js', {
    scope: '/'
  });
}
