var Denali = Denali || {};

Denali.Analytics = (function () {
  'use strict';

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
    sendPageview: sendPageview
  };
})();
