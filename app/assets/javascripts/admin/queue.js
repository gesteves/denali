var Denali = Denali || {};

Denali.Queue = (function ($) {
  'use strict';

  var opts = {
    queue_selector : '.js-queue'
  };

  var stopSort = function (e, ui) {
    updatePosition(ui.item);
  };

  var updatePosition = function ($element) {
    var id = $element.data('id');
    var index = $(opts.queue_selector).find('#entry-' + id).index();
    $.post('/admin/entries/' + id + '/reposition.js', {
      id : id,
      position: index + 1
    });
  };

  var init = function () {
    var $queue = $(opts.queue_selector);
    
    if ($queue.length === 0) {
      return;
    }

    $queue.on('sortstop', stopSort);
    $queue.sortable();
  };

  return {
    init: init
  };
})(jQuery);

Denali.Queue.init();
