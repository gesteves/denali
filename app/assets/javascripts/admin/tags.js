var Denali = Denali || {};

Denali.Tags = (function ($) {
  'use strict';

  var opts = {
    selector  : '.js-delete-tag',
  };

  var init = function () {
    $(opts.selector).on('click', deleteTag);
  };

  var deleteTag = function () {
    var $link = $(this);
    if (window.confirm('Are you sure you want to delete the “' + $link.data('tag-name') +  '” tag?')) {
      $.ajax({
        url: $link.attr('href') + '.json',
        type: 'DELETE',
        success: function() {
          $link.parents('tr').fadeOut();
        }
      });
    }
    return false;
  };

  return {
    init: init
  };
})(jQuery);
