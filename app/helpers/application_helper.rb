module ApplicationHelper

  def responsive_image_tag(photo:, srcset: [3360], src: nil, sizes: '100vw', aspect_ratio: nil, html_options: {})
    return placeholder_image_tag(srcset: srcset, sizes: sizes, aspect_ratio: aspect_ratio, html_options: html_options) unless photo&.has_dimensions?
    # Pre-calculate crop once and reuse for all formats to avoid repeated queries
    crop = photo.calculate_crop({ aspect_ratio: aspect_ratio }.compact)
    base_opts = { crop: crop }.compact
    _, jpg_srcset = photo.srcset(srcset: srcset, src: src, opts: base_opts.merge(aspect_ratio: aspect_ratio).compact)
    html_options.reverse_merge!({
      src: photo.sitemap_url,
      width: photo.width,
      height: aspect_ratio.present? ? photo.height_from_aspect_ratio(aspect_ratio) : photo.height,
      alt: photo.alt_text,
      loading: 'lazy',
      decoding: 'async'
    })
    tag.picture do
      ['avif', 'webp'].each do |format|
        format_srcset = photo.srcset(srcset: srcset, opts: base_opts.merge(aspect_ratio: aspect_ratio, format: format).compact).last
        concat(tag.source(sizes: sizes, srcset: format_srcset, type: "image/#{format}"))
      end
      concat(tag.source(sizes: sizes, srcset: jpg_srcset, type: 'image/jpeg'))
      concat(content_tag :img, nil, html_options)
    end
  end

  def placeholder_image_tag(srcset: [3360], sizes: '100vw', aspect_ratio: nil, html_options: {})
    return '' unless @photoblog.placeholder_processed?
    src, srcset = @photoblog.placeholder_srcset(srcset: srcset, opts: { aspect_ratio: aspect_ratio })
    html_options.reverse_merge!({
      srcset: srcset,
      src: src,
      sizes: sizes,
      width: @photoblog.placeholder.metadata[:width],
      height: aspect_ratio.present? ? @photoblog.placeholder_height_from_aspect_ratio(aspect_ratio) : @photoblog.placeholder.metadata[:height],
      alt: '',
      loading: 'eager'
    }.compact)
    content_tag :img, nil, html_options
  end

  def inline_svg(icon, class_name: '', aria_hidden: true)
    render partial: "partials/svg/#{icon.to_s}", locals: { class_name: "#{class_name} #{class_name}--#{icon}".strip, aria_hidden: aria_hidden }
  end

  def css_placeholder_background(photo)
    svg_uri = photo.blurhash_svg_data_uri
    if svg_uri.present?
      "--placeholder:url('#{svg_uri}');"
    else
      ''
    end
  end
end
