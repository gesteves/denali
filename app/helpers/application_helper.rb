module ApplicationHelper

  def responsive_image_tag(photo, photo_key, html_options = {})
    src, srcset = photo.srcset(photo_key)
    width = is_variant_square?(photo_key) ? photo.srcset_widths(photo_key).last: photo.width
    height = is_variant_square?(photo_key) ? photo.srcset_widths(photo_key).last : photo.height
    html_options.reverse_merge!({
      srcset: srcset,
      src: src,
      sizes: Photo.sizes(photo_key),
      width: width,
      height: height,
      loading: 'eager'
    })
    content_tag :img, nil, html_options
  end

  def lazy_responsive_image_tag(photo, photo_key, html_options = {})
    src, srcset = photo.srcset(photo_key)
    sizes = Photo.sizes(photo_key)
    width = is_variant_square?(photo_key) ? photo.srcset_widths(photo_key).last : photo.width
    height = is_variant_square?(photo_key) ? photo.srcset_widths(photo_key).last : photo.height
    lazy_img = content_tag(:img, nil, html_options.merge({
      'data-srcset': srcset,
      'data-src': src,
      'data-controller': 'lazy-load',
      sizes: sizes,
      src: 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
      width: width,
      height: height,
      loading: 'lazy'
    }))

    noscript = content_tag :noscript do
      content_tag :img, nil, html_options.merge({
        srcset: srcset,
        src: src,
        sizes: sizes,
        width: width,
        height: height,
        loading: 'lazy'
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

  def css_gradient_stops(photo)
    return '' if photo.color_palette.blank?
    palette = photo.color_palette.split(',').sample(2)
    "--gradient-start:#{palette.first};--gradient-end:#{palette.last};".html_safe
  end

  def css_aspect_ratio(photo)
    return '--aspect-ratio:0' if photo.width.blank? || photo.height.blank?
    "--aspect-ratio:#{photo.height.to_f/photo.width.to_f};"
  end

  def inline_asset(filename, opts = {})
    opts.reverse_merge!(strip_charset: false)
    if opts[:strip_charset]
      Rails.application.assets[filename].to_s.gsub('@charset "UTF-8";', '').html_safe
    else
      Rails.application.assets[filename].to_s.html_safe
    end
  end

  def sponsored_link_to(name = nil, options = nil, html_options = nil, &block)
    html_options.merge!(rel: 'sponsored nofollow noopener', target: '_blank')
    link_to(name, options, html_options, &block)
  end

  def sponsored_link_to_if(condition, name, options = {}, html_options = {}, &block)
    html_options.merge!(rel: 'sponsored nofollow noopener', target: '_blank')
    link_to_if(condition, name, options, html_options, &block)
  end
end
