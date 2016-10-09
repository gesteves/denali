//= require ./vendors/loadjs
//= require ./vendors/loadcss
//= require ./application/map

'use strict';

if (document.readyState !== 'loading') {
  Denali.Map.init();
}

document.addEventListener('turbolinks:load', Denali.Map.init);
