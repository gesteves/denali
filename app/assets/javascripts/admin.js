//= require jquery/dist/jquery
//= require jquery-ui-dist/jquery-ui
//= require intersection-observer/intersection-observer
//= require awesomplete/awesomplete
//= require clipboard/dist/clipboard
//= require jquery_ujs
//= require_tree ./admin

'use strict';

if (document.readyState !== 'loading') {
  Denali.Entries.init();
  Denali.Flash.init();
  Denali.Tags.init();
  Denali.Clipboard.init();
}

document.addEventListener('DOMContentLoaded', Denali.Entries.init);
document.addEventListener('DOMContentLoaded', Denali.Flash.init);
document.addEventListener('DOMContentLoaded', Denali.Tags.init);
document.addEventListener('DOMContentLoaded', Denali.Clipboard.init);
