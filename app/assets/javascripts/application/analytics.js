var Denali = Denali || {};

Denali.Analytics = (function () {
  'use strict';

  var init = function () {
    if (typeof Turbolinks !== 'undefined' && Turbolinks.supported) {
      document.addEventListener('page:change', sendPageview);
    } else {
      sendPageview();
    }
  };

  var sendPageview = function () {
    if (typeof ga !== 'undefined') {
      ga('send', {
        hitType  : 'pageview',
        location : window.location.href,
        page     : window.location.pathname,
        title    : document.title
      });
    }
  };

  return {
    init : init
  };
})();

Denali.Analytics.init();
