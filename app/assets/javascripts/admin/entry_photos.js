var Denali = Denali || {};

Denali.EntryPhotos = (function ($) {
  'use strict';

  var opts = {
    $photos_container : $('.admin-form__photos'),
    $photo_list       : $('.admin-form__photos-list'),
    fields            : '.admin-form__fields',
    hidden_class      : 'admin-form__fields--hidden',
    source_url_field  : '.js-photo-source-url',
    dropbox_button    : '.js-photo-dropbox',
    source_file_field : '.js-photo-source-file',
    thumbnail         : '.js-photo-thumb',
    add_button        : '.js-photo-add',
    delete_button     : '.js-photo-delete',
    destroy_field     : '.js-photo-destroy',
    position_field    : '.js-photo-position',
    add_photo_endpoint: '/admin/entries/photo',
    photo_container   : '.admin-form__photo'
  };

  var addPhotoFields = function (e) {
    e.preventDefault();
    $.ajax(opts.add_photo_endpoint, {
      dataType: 'html',
      success: function (data) {
        opts.$photo_list.append(data);
      }
    });
  };

  var deletePhoto = function (e) {
    e.preventDefault();
    var photo = $(this).parents(opts.photo_container);
    var delete_field = photo.find(opts.destroy_field);
    if (delete_field.length === 0) {
      photo.remove();
    } else {
      delete_field.val('true');
      photo.hide();
    }
  };

  var addFromDropbox = function (e) {
    e.preventDefault();
    var photo = $(this).parents(opts.photo_container);

    Dropbox.choose({
      linkType: 'direct',
      extensions: ['.jpg'],
      success: function (files) {
        showThumbnail(photo, files[0].link);
      }
    });
  };

  var showThumbnail = function (photo, url) {
    photo.find(opts.thumbnail).attr('src', url);
    photo.find(opts.source_url_field).val(url);
    photo.find(opts.fields).toggleClass(opts.hidden_class);
    updatePositions();
  };

  var updatePositions = function () {
    $(opts.position_field).each(function (index) {
      $(this).val(index + 1);
    });
  };

  var init = function () {
    if (opts.$photos_container.length === 0) {
      return;
    }

    opts.$photos_container.on('click', opts.add_button, addPhotoFields);
    opts.$photos_container.on('click', opts.delete_button, deletePhoto);
    opts.$photos_container.on('click', opts.dropbox_button, addFromDropbox);
  };

  return {
    init: init
  };
})(jQuery);

Denali.EntryPhotos.init();
