var Denali = Denali || {};

Denali.Entries = (function ($) {
  'use strict';

  var opts = {
    photos_container_selector : '.form__photos',
    photo_list_selector       : '.form__photos-list',
    fields            : '.form__fields',
    hidden_class      : 'form__fields--hidden',
    source_url_field  : '.js-photo-source-url',
    dropbox_button    : '.js-photo-dropbox',
    source_file_field : '.js-photo-source-file',
    thumbnail         : '.js-photo-thumb',
    add_button        : '.js-photo-add',
    delete_button     : '.js-photo-delete',
    destroy_field     : '.js-photo-destroy',
    file_button       : '.js-photo-file-button',
    position_field    : '.js-photo-position',
    focal_x_field     : '.js-photo-focal-x',
    focal_y_field     : '.js-photo-focal-y',
    single_tag        : '.js-tags-single',
    multiple_tags     : '.js-tags-multiple',
    focal_point_marker: '.js-photo-focal-point',
    add_photo_endpoint: '/admin/entries/photo',
    photo_container   : '.form__photo'
  };

  var $photo_list;

  var addPhotoFields = function (e) {
    var new_photo;
    e.preventDefault();
    $.ajax(opts.add_photo_endpoint, {
      dataType: 'html',
      success: function (data) {
        new_photo = $(data);
        new_photo.find(opts.single_tag).each(function () {
          new Awesomplete(this);
        });
        $photo_list.append(new_photo);
      }
    });
  };

  var deletePhoto = function (e) {
    e.preventDefault();
    var photo = $(this).parents(opts.photo_container);
    var delete_field = photo.find(opts.destroy_field);
    if (photo.find(opts.fields).last().hasClass(opts.hidden_class) || window.confirm('Are you sure you want to remove this photo?')) {
      if (delete_field.length === 0) {
        photo.slideUp(function () {
          $(this).remove();
        });
      } else {
        photo.find('[required]').removeAttr('required');
        delete_field.val('true');
        photo.slideUp();
      }
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
    $.ajax(opts.add_photo_endpoint + '?count=' + files.length, {
      dataType: 'html',
      success: function (data) {
        new_photo = $(data);
        new_photo.find(opts.single_tag).each(function () {
          new Awesomplete(this);
        });
        $photo_list.append(new_photo);
        new_photo.filter(opts.photo_container).each(function (i) {
          photo = $(this);
          source_url = photo.find(opts.source_url_field).val(files[i].link);
          showThumbnail(photo, files[i].link);
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

  var initTags = function () {
    $(opts.multiple_tags).each(function () {
      new Awesomplete(this, {
        list: '#datalist-tags',
        filter: function (text, input) {
          return Awesomplete.FILTER_CONTAINS(text, input.match(/[^,]*$/)[0]);
        },
        replace: function (text) {
          var before = this.input.value.match(/^.+,\s*|/)[0];
          this.input.value = before + text + ', ';
        }
      });
    });
    $(opts.single_tag).each(function () {
      new Awesomplete(this);
    });
  };

  var initFocalPoints = function () {
    $photo_list.each(function () {
      showFocalPoint($(this));
    });
  };

  var setFocalPoint = function (e) {
    var $image = $(this);
    var $parent = $image.parents(opts.photo_container);
    var focal_x = (e.pageX - $image.offset().left)/$image.width();
    var focal_y = (e.pageY - $image.offset().top)/$image.height();

    $parent.find(opts.focal_x_field).val(focal_x);
    $parent.find(opts.focal_y_field).val(focal_y);

    showFocalPoint($parent);
    return false;
  };

  var showFocalPoint = function ($element) {
    var $thumbnail = $element.find('img');
    var focal_x = $element.find(opts.focal_x_field).val();
    var focal_y = $element.find(opts.focal_y_field).val();
    var $marker = $element.find(opts.focal_point_marker);
    if (focal_x !== '' && focal_y !== '') {
      $marker.css({
        top: ($thumbnail.height() * focal_y) - 25,
        left: ($thumbnail.width() * focal_x) - 25
      }).show();
    }
  };

  var initPhotos = function () {
    var $photos_container = $(opts.photos_container_selector);

    if ($photos_container.length === 0) {
      return;
    }

    $photo_list = $(opts.photo_list_selector);
    $(window).on('load', initFocalPoints);
    $photos_container.on('click', opts.add_button, addPhotoFields);
    $photos_container.on('click', opts.delete_button, deletePhoto);
    $photos_container.on('click', opts.dropbox_button, addFromDropbox);
    $photos_container.on('click', opts.file_button, triggerFileInput);
    $photos_container.on('click', opts.source_file_field, function (e) {
      e.stopPropagation();
    });
    $photos_container.on('click', 'img', setFocalPoint);
    $photos_container.on('change', opts.source_file_field, addFromFile);
    $photos_container.on('keyup', opts.source_url_field, addFromUrl);
    $photo_list.on('sortstop', updatePositions);
    $photo_list.sortable();
  };

  var init = function () {
    initPhotos();
    initTags();
  };

  return {
    init: init
  };
})(jQuery);
