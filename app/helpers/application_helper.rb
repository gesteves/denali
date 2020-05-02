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
    tag :img, html_options
  end

  def is_variant_square?(key)
    PHOTOS[key]['square'].present?
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
end
