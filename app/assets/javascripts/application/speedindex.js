//= require ../vendors/speedindex

var Denali = Denali || {};

Denali.SpeedIndex = (function () {
  'use strict';

  var init = function () {
    var body, label;
    if (typeof RUMSpeedIndex() !== 'undefined') {
      body = document.querySelector('body');
      label = body.getAttribute('data-context');
      ga('send', {
        hitType: 'timing',
        timingCategory: 'RUM',
        timingVar: 'speedindex',
        timingValue: Math.round(RUMSpeedIndex()),
        timingLabel: label
      });
    }
  };

  return {
    init : init
  };
})();

if (document.readyState === 'complete') {
  Denali.SpeedIndex.init();
} else {
  window.addEventListener('load', Denali.SpeedIndex.init, true);
}
