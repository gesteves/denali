//= require turbolinks
//= require ./vendors/loadjs
//= require ./vendors/loadcss
//= require ./vendors/cssrelpreload
//= require_tree ./application

'use strict';

Turbolinks.enableProgressBar();

// I'm loading scripts async, so if the page has finished loading then
// I need to init these scripts directly, because the `page:change`
// event has already fired.
if (document.readyState !== 'loading') {
  Denali.SocialShare.init();
  Denali.ImageZoom.init();
  Denali.LazyLoad.init();
  Denali.Map.init();
  Denali.Analytics.init();
}

document.addEventListener('DOMContentLoaded', Denali.Analytics.init);
document.addEventListener('page:change', Denali.SocialShare.init);
document.addEventListener('page:change', Denali.ImageZoom.init);
document.addEventListener('page:change', Denali.LazyLoad.init);
document.addEventListener('page:change', Denali.Map.init);
document.addEventListener('orientationchange', Denali.ImageZoom.init);
window.addEventListener('resize', Denali.ImageZoom.handleResize);
