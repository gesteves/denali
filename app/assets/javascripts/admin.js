//= require ./vendors/jquery
//= require ./vendors/jquery_ui
//= require ./vendors/awesomplete
//= require jquery_ujs
//= require_tree ./admin
//= require ./application/lazy_load

'use strict';

if (document.readyState !== 'loading') {
  Denali.Entries.init();
  Denali.Flash.init();
  Denali.Queue.init();
  Denali.LazyLoad.init();
  Denali.Tags.init();
}

document.addEventListener('DOMContentLoaded', Denali.Entries.init);
document.addEventListener('DOMContentLoaded', Denali.Flash.init);
document.addEventListener('DOMContentLoaded', Denali.Queue.init);
document.addEventListener('DOMContentLoaded', Denali.LazyLoad.init);
document.addEventListener('DOMContentLoaded', Denali.Tags.init);
