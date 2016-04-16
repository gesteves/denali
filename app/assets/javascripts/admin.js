//= require turbolinks
//= require ./vendors/jquery
//= require ./vendors/jquery_ui
//= require ./vendors/awesomplete
//= require_tree ./admin
//= require jquery_ujs

'use strict';

Turbolinks.enableProgressBar();

if (document.readyState !== 'loading') {
  Denali.Entries.init();
  Denali.Flash.init();
  Denali.Queue.init();
}

document.addEventListener('page:change', Denali.Entries.init);
document.addEventListener('page:change', Denali.Flash.init);
document.addEventListener('page:change', Denali.Queue.init);
