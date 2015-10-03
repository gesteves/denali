var Denali = Denali || {};

Denali.Queue = (function ($) {
  'use strict';

  var opts = {
    link_selector  : '[data-queue]',
    entry_selector : '.entry',
    list_selector  : '.entry-list'
  };

  var $list;

  var updatePosition = function () {
    $list = $(opts.list_selector);
    var $link = $(this);
    var $entry = $link.parents(opts.entry_selector);
    var direction = $link.data('queue');
    $.post($link.attr('href'));
    switch (direction) {
      case 'top':
        moveToTop($entry);
        break;
      case 'up':
        moveUp($entry);
        break;
      case 'down':
        moveDown($entry);
        break;
      case 'bottom':
        moveToBottom($entry);
        break;
    }
    return false;
  };

  var moveToTop = function ($entry) {
    $entry.detach();
    $list.prepend($entry);
  };

  var moveUp = function ($entry) {
    var $previous = $entry.prev();
    if ($previous.length) {
      $entry.detach();
      $previous.before($entry);
    }
  };

  var moveDown = function ($entry) {
    var $next = $entry.next();
    if ($next.length) {
      $entry.detach();
      $next.after($entry);
    }
  };

  var moveToBottom = function ($entry) {
    $entry.detach();
    $list.append($entry);
  };

  var init = function () {
    $(opts.link_selector).on('click', updatePosition);
  };

  return {
    init: init
  };
})(jQuery);

Denali.Queue.init();
