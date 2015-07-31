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

  var trackEvent = function(name, data) {
    if (typeof _gs !== 'undefined') {
      if (typeof data === 'undefined') {
        _gs('event', name);
      } else {
        _gs('event', name, data);
      }
    }
  };

  return {
    init : init,
    trackEvent : trackEvent
  };
})();

Denali.Analytics.init();
