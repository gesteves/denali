var Denali = Denali || {};

Denali.Tags = (function ($) {
  'use strict';

  var opts = {
    selector: '.table',
    delete_selector  : '.js-delete-tag',
    edit_selector  : '.js-edit-tag',
  };

  var init = function () {
    $(opts.selector).on('click', opts.delete_selector, deleteTag);
    $(opts.selector).on('click', opts.edit_selector, editTag);
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

  var editTag = function () {
    var $link = $(this);
    var prompt = window.prompt('What do you want to replace the “' + $link.data('tag-name') +  '” tag with?', $link.data('tag-name'));
    if (prompt.replace(/\s/g, '').length > 0 && prompt !== null) {
      $.ajax({
        url: $link.attr('href') + '.js',
        type: 'PATCH',
        data: {
          name: prompt
        },
        success: function(data) {
          $link.parents('tr').replaceWith(data);
        }
      });
    }
    return false;
  };

  return {
    init: init
  };
})(jQuery);
