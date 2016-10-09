//= require turbolinks
//= require ./vendors/cssrelpreload
//= require ./application/analytics
//= require ./application/image_zoom
//= require ./application/lazy_load

'use strict';

if (document.readyState !== 'loading') {
  Denali.ImageZoom.init();
  Denali.LazyLoad.init();
  Denali.Analytics.sendPageview();
}

document.addEventListener('turbolinks:load', Denali.ImageZoom.init);
document.addEventListener('turbolinks:load', Denali.LazyLoad.init);
document.addEventListener('turbolinks:load', Denali.Analytics.sendPageview);
document.addEventListener('orientationchange', Denali.ImageZoom.init);
window.addEventListener('resize', Denali.ImageZoom.handleResize);
