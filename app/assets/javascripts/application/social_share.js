var Denali = Denali || {};

Denali.SocialShare = (function () {
  'use strict';

  var opts = {
    buttons: '[data-social-share]'
  };

  var init = function () {
    var buttons = document.querySelectorAll(opts.buttons);
    var button;

    for (var i = 0; i < buttons.length; i++) {
      button = buttons[i];
      button.addEventListener('click', openShareWindow);
    }
  };

  var openShareWindow = function (e) {
    e.preventDefault();
    var link = this.getAttribute('href');
    window.open(link, 'Share', 'width=500,height=400');
  };

  return {
    init : init
  };
})();

document.addEventListener('page:change', function() {
  'use strict';
  Denali.SocialShare.init();
});
