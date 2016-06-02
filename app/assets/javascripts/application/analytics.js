var Denali = Denali || {};

Denali.Analytics = (function () {
  'use strict';

  var sendPageview = function () {
    if (typeof _gs !== 'undefined') {
      _gs('track', window.location.href, document.title);
    }
  };

  return {
    sendPageview: sendPageview
  };
})();
