//= require turbolinks
//= require ./vendors/loadjs
//= require_tree ./application

'use strict';

// I'm loading scripts async, so if the page has finished loading then
// I need to init these scripts directly, because the `turbolinks:load`
// event has already fired.
if (document.readyState !== 'loading') {
  Denali.ImageZoom.init();
  Denali.LazyLoad.init();
  Denali.Map.init();
  Denali.Analytics.sendPageview();
}

document.addEventListener('turbolinks:load', Denali.ImageZoom.init);
document.addEventListener('turbolinks:load', Denali.LazyLoad.init);
document.addEventListener('turbolinks:load', Denali.Map.init);
document.addEventListener('turbolinks:load', Denali.Analytics.sendPageview);
document.addEventListener('orientationchange', Denali.ImageZoom.init);
window.addEventListener('resize', Denali.ImageZoom.handleResize);
