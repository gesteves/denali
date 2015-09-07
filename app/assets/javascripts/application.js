//= require ./vendor/picturefill
//= require ./vendor/loadcss
//= require ./vendor/fastclick
//= require turbolinks
//= require_tree ./application

Turbolinks.enableProgressBar();

// I'm loading scripts async, so if the page has finished loading then
// I need to init these scripts directly, because the `page:change`
// event has already fired.
if (document.readyState !== 'loading') {
  Denali.SocialShare.init();
  Denali.Shortcuts.init();
  Denali.ImageZoom.init();
  Denali.Analytics.sendPageview();
  FastClick.attach(document.body);
}

// Attach event listeners
document.addEventListener('page:change', picturefill);
document.addEventListener('page:change', Denali.SocialShare.init);
document.addEventListener('page:change', Denali.Shortcuts.init);
document.addEventListener('page:change', Denali.ImageZoom.init);
document.addEventListener('page:change', Denali.Analytics.sendPageview);
document.addEventListener('page:change', function () {
  FastClick.attach(document.body);
});
document.addEventListener('orientationchange', Denali.ImageZoom.init);
document.addEventListener('keydown', Denali.Shortcuts.handleKeyPress);
