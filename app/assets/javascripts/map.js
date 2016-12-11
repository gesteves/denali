//= require ./vendors/loadjs
//= require ./application/map

'use strict';

if (document.readyState !== 'loading') {
  Denali.Map.init();
}

document.addEventListener('DOMContentLoaded', Denali.Map.init);
