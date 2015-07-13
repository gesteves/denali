//= require ./vendor/picturefill
//= require turbolinks
//= require_tree ./application

document.addEventListener('keydown', Denali.Shortcuts.handleKeyPress);
document.addEventListener('page:change', Denali.ImageZoom.init);
document.addEventListener('page:change', Denali.Shortcuts.init);
document.addEventListener('page:change', Denali.SocialShare.init);
document.addEventListener('page:change', picturefill);
