var Denali = Denali || {};

Denali.Analytics = (function () {
  'use strict';

  var sendPageview = function () {
    if (typeof gs !== 'undefined') {
      _gs('track', window.location.href, document.title);
    }
  };

  return {
    sendPageview: sendPageview
  };
})();
