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
    if (typeof _gs !== 'undefined') {
      _gs('track');
    }
  };

  return {
    init : init
  };
})();

Denali.Analytics.init();
