//= require ../vendors/speedindex

var Denali = Denali || {};

Denali.SpeedIndex = (function () {
  'use strict';

  var init = function () {
    if (typeof ga !== 'undefined' && typeof RUMSpeedIndex() !== 'undefined') {
      ga('send', {
        hitType: 'timing',
        timingCategory: 'RUM',
        timingVar: 'speedindex',
        timingValue: RUMSpeedIndex()
      });
    }
  };

  return {
    init : init
  };
})();

if (document.readyState !== 'loading') {
  Denali.SpeedIndex.init();
} else {
  document.addEventListener('DOMContentLoaded', Denali.SpeedIndex.init);
}
