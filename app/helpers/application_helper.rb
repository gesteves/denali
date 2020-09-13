module ApplicationHelper

  def responsive_image_tag(photo:, srcset: [3360], sizes: '100vw', square: false, html_options: {})
    return placeholder_image_tag(srcset: srcset, sizes: sizes, square: square, html_options: html_options) unless photo&.processed?
    src, srcset = photo.srcset(srcset: srcset, square: square)
    html_options.reverse_merge!({
      srcset: srcset,
      src: src,
      sizes: sizes,
      width: photo.width,
      height: square ? photo.width : photo.height,
      alt: photo.alt_text,
      loading: 'eager'
    })
    tag :img, html_options
  end

  def placeholder_image_tag(srcset: [3360], sizes: '100vw', square: false, html_options: {})
    return '' unless @photoblog.logo.attached?
    src, srcset = @photoblog.placeholder_srcset(srcset: srcset)
    html_options.reverse_merge!({
      srcset: srcset,
      src: src,
      sizes: sizes,
      alt: '',
      loading: 'eager'
    })
    tag :img, html_options
  end

  def inline_svg(icon, class_name: '', aria_hidden: true)
    render partial: "partials/svg/#{icon.to_s}.html.erb", locals: { class_name: "#{class_name} #{class_name}--#{icon}".strip, aria_hidden: aria_hidden }
  end

  def css_gradient_stops(photo)
    return '' if photo.color_palette.blank?
    palette = photo.color_palette.split(',').sample(2)
    "--gradient-start:#{palette.first};--gradient-end:#{palette.last};".html_safe
  end

  def css_aspect_ratio(photo)
    return '--aspect-ratio:0' unless photo.processed?
    "--aspect-ratio:#{(photo.height.to_f/photo.width.to_f).floor(2)};"
  end

  def inline_asset(filename, opts = {})
    opts.reverse_merge!(strip_charset: false)
    if opts[:strip_charset]
      Rails.application.assets[filename].to_s.gsub('@charset "UTF-8";', '').html_safe
    else
      Rails.application.assets[filename].to_s.html_safe
    end
  end

  def remove_widows(text)
    words = text.split(/\s+/)
    return text if words.size == 1
    last_words = words.pop(2).join('&nbsp;')
    words.append(last_words).join(' ')
  end
end
