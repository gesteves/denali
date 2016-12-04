//= require turbolinks
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

document.addEventListener('turbolinks:load', Denali.Entries.init);
document.addEventListener('turbolinks:load', Denali.Flash.init);
document.addEventListener('turbolinks:load', Denali.Queue.init);
document.addEventListener('turbolinks:load', Denali.LazyLoad.init);
document.addEventListener('turbolinks:load', Denali.Tags.init);
