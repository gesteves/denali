module ApplicationHelper

  def responsive_image_tag(photo, photo_key, html_options = {})
    html_options.reverse_merge!({
      srcset: get_srcset(photo, photo_key),
      sizes: get_sizes(photo_key),
      src: get_src(photo, photo_key)
    })
    content_tag :img, nil, html_options
  end

  def amp_image_tag(photo, photo_key, html_options = {})
    html_options.reverse_merge!({
      srcset: get_srcset(photo, photo_key),
      sizes: get_sizes(photo_key),
      src: get_src(photo, photo_key),
      width: photo.width,
      height: photo.height,
      layout: 'responsive'
    })
    content_tag 'amp-img', nil, html_options
  end

  def lazy_responsive_image_tag(photo, photo_key, html_options = {})
    srcset = get_srcset(photo, photo_key)
    src = get_src(photo, photo_key)
    sizes = get_sizes(photo_key)

    lazy_img = content_tag(:img, nil, html_options.merge({
      'data-srcset': srcset,
      'data-src': src,
      'data-controller': 'lazy-load',
      sizes: sizes,
      src: 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7'
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

  def get_src(photo, photo_key)
    variant = PHOTOS[photo_key]
    quality = variant['quality']
    square = variant['square'].present?
    width = variant['src']
    auto = variant['auto'] || 'format'
    photo.url(w: width, q: quality, square: square, auto: auto)
  end

  def get_srcset(photo, photo_key)
    variant = PHOTOS[photo_key]
    quality = variant['quality']
    square = variant['square'].present?
    auto = variant['auto'] || 'format'
    photo.srcset(variant['srcset'], { q: quality, square: square, auto: auto })
  end

  def get_sizes(photo_key)
    PHOTOS[photo_key]['sizes'].join(', ')
  end

  def inline_svg(icon, svg_class = "icon")
    render partial: "partials/svg/#{icon}.html.erb", locals: { svg_class: "#{svg_class} #{svg_class}--#{icon}" }
  end

  def intrinsic_ratio_padding(photo)
    return '' if photo.width.blank? || photo.height.blank?
    padding = (photo.height.to_f/photo.width.to_f) * 100
    "padding-top:#{padding}%".html_safe
  end

  def intrinsic_ratio_width(photo)
    return '' if photo.width.blank? || photo.height.blank?
    width = (photo.width.to_f/photo.height.to_f) * 100
    "width:#{width}vh".html_safe
  end

  def image_placeholder(photo)
    return '' if photo.color_palette.blank?
    palette = photo.color_palette.split(',').sample(2).join(',')
    "background:linear-gradient(to bottom right, #{palette})".html_safe
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
