module ApplicationHelper

  def responsive_image_tag(photo, photo_key, html_options = {})
    src, srcset = photo.srcset(photo_key)
    intrinsic_size = is_variant_square?(photo_key) ? '1x1' : "#{photo.width}x#{photo.height}"
    html_options.reverse_merge!({
      srcset: srcset,
      src: src,
      sizes: Photo.sizes(photo_key),
      intrinsicsize: intrinsic_size
    })
    content_tag :img, nil, html_options
  end

  def amp_image_tag(photo, photo_key, html_options = {})
    src, srcset = photo.srcset(photo_key)
    html_options.reverse_merge!({
      srcset: srcset,
      src: src,
      sizes: Photo.sizes(photo_key),
      width: photo.width,
      height: photo.height,
      layout: 'responsive'
    })
    content_tag 'amp-img', nil, html_options
  end

  def lazy_responsive_image_tag(photo, photo_key, html_options = {})
    src, srcset = photo.srcset(photo_key)
    sizes = Photo.sizes(photo_key)
    intrinsic_size = is_variant_square?(photo_key) ? '1x1' : "#{photo.width}x#{photo.height}"
    lazy_img = content_tag(:img, nil, html_options.merge({
      'data-srcset': srcset,
      'data-src': src,
      'data-controller': 'lazy-load',
      sizes: sizes,
      src: 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
      intrinsicsize: intrinsic_size
    }))

    noscript = content_tag :noscript do
      content_tag :img, nil, html_options.merge({
        srcset: srcset,
        src: src,
        sizes: sizes
      })
    end

    lazy_img + noscript
  end

  def is_variant_square?(key)
    PHOTOS[key]['square'].present?
  end

  def inline_svg(icon, svg_class = "icon")
    render partial: "partials/svg/#{icon}.html.erb", locals: { svg_class: "#{svg_class} #{svg_class}--#{icon}" }
  end

  def gradient_css_props(photo)
    return '' if photo.color_palette.blank?
    palette = photo.color_palette.split(',').sample(2)
    "--gradient-start-color:#{palette.first};--gradient-end-color:#{palette.last};".html_safe
  end

  def photo_dimensions_css_props(photo)
    return '' if photo.width.blank? || photo.height.blank?
    "--photo-width:#{photo.width};--photo-height:#{photo.height};"
  end

  def inline_asset(filename, opts = {})
    opts.reverse_merge!(strip_charset: false)
    if opts[:strip_charset]
      Rails.application.assets[filename].to_s.gsub('@charset "UTF-8";', '').html_safe
    else
      Rails.application.assets[filename].to_s.html_safe
    end
  end
end
