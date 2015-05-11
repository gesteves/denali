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
    file_button       : '.js-photo-file-button',
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
    } else if (window.confirm('Are you sure you want to delete this photo?')) {
      delete_field.val('true');
      photo.slideUp();
    }
  };

  var addFromDropbox = function (e) {
    e.preventDefault();
    var photo = $(this).parents(opts.photo_container);
    Dropbox.choose({
      linkType: 'direct',
      extensions: ['.jpg', '.jpeg'],
      multiselect: true,
      success: function (files) {
        createDropboxImages(files);
        photo.remove();
      }
    });
  };

  var createDropboxImages = function (files) {
    var new_photo,
        photo,
        source_url;
    console.log(files.length);
    $.ajax(opts.add_photo_endpoint + '?count=' + files.length, {
      dataType: 'html',
      success: function (data) {
        new_photo = $(data);
        opts.$photo_list.append(new_photo);
        new_photo.filter(opts.photo_container).each(function (i) {
          photo = $(this);
          source_url = photo.find(opts.source_url_field).val(files[i].link).trigger('change');
        });
        updatePositions();
      }
    });
  };

  var addFromUrl = function () {
    var source_url = $(this);
    var photo = source_url.parents(opts.photo_container);
    if (source_url.val().match(/\.jpe?g$/)) {
      showThumbnail(photo, $(this).val());
      updatePositions();
    }
  };

  var addFromFile = function () {
    var input = $(this);
    var files = input[0].files;
    var photo = input.parents(opts.photo_container);

    if (files[0].type.match(/\jpe?g$/)) {
      setUpFileReader(photo, files[0]);
      updatePositions();
    }
  };

  var setUpFileReader = function(photo, file) {
    var reader;
    reader = new FileReader();
    reader.onload = function (e) {
      showThumbnail(photo, e.target.result);
    };
    reader.readAsDataURL(file);
  };

  var showThumbnail = function (photo, url) {
    photo.find(opts.thumbnail).attr('src', url);
    photo.find(opts.fields).toggleClass(opts.hidden_class);
  };

  var updatePositions = function () {
    $(opts.position_field).each(function (index) {
      $(this).val(index + 1);
    });
  };

  var triggerFileInput = function (e) {
    e.preventDefault();
    $(this).find(opts.source_file_field).trigger('click');
  };

  var init = function () {
    if (opts.$photos_container.length === 0) {
      return;
    }

    opts.$photos_container.on('click', opts.add_button, addPhotoFields);
    opts.$photos_container.on('click', opts.delete_button, deletePhoto);
    opts.$photos_container.on('click', opts.dropbox_button, addFromDropbox);
    opts.$photos_container.on('click', opts.file_button, triggerFileInput);
    opts.$photos_container.on('click', opts.source_file_field, function (e) {
      e.stopPropagation();
    });
    opts.$photos_container.on('change', opts.source_file_field, addFromFile);
    opts.$photos_container.on('change', opts.source_url_field, addFromUrl);
    opts.$photo_list.on('sortstop', updatePositions);

    opts.$photo_list.sortable();
  };

  return {
    init: init
  };
})(jQuery);

Denali.EntryPhotos.init();
