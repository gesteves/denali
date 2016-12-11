//= require ./application/analytics
//= require ./application/image_zoom
//= require ./application/lazy_load

'use strict';

if (document.readyState !== 'loading') {
  Denali.ImageZoom.init();
  Denali.LazyLoad.init();
  Denali.Analytics.sendPageview();
}

document.addEventListener('DOMContentLoaded', Denali.ImageZoom.init);
document.addEventListener('DOMContentLoaded', Denali.LazyLoad.init);
document.addEventListener('DOMContentLoaded', Denali.Analytics.sendPageview);
document.addEventListener('orientationchange', Denali.ImageZoom.init);
window.addEventListener('resize', Denali.ImageZoom.handleResize);
