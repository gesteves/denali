module ApplicationHelper

  def responsive_image_tag(photo:, srcset: [3360], sizes: '100vw', aspect_ratio: nil, html_options: {})
    return placeholder_image_tag(srcset: srcset, sizes: sizes, aspect_ratio: aspect_ratio, html_options: html_options) unless photo&.processed?
    jpg_src, jpg_srcset = photo.srcset(srcset: srcset, opts: { ar: aspect_ratio, q: ENV['IMAGE_QUALITY_JPG'] }.compact)
    html_options.reverse_merge!({
      src: jpg_src,
      width: photo.width,
      height: aspect_ratio.present? ? photo.height_from_aspect_ratio(aspect_ratio) : photo.height,
      alt: photo.alt_text,
      loading: 'eager',
      decoding: 'async'
    })
    tag.picture do
      ENV['IMAGE_FORMATS']&.split(',')&.each do |format|
        format_srcset = photo.srcset(srcset: srcset, opts: { ar: aspect_ratio, fm: format, q: ENV["IMAGE_QUALITY_#{format.upcase}"] }.compact).last
        concat(tag.source(sizes: sizes, srcset: format_srcset, type: "image/#{format}"))
      end
      concat(tag.source(sizes: sizes, srcset: jpg_srcset, type: 'image/jpeg'))
      concat(tag.img(html_options))
    end
  end

  def placeholder_image_tag(srcset: [3360], sizes: '100vw', aspect_ratio: nil, html_options: {})
    return '' unless @photoblog.placeholder_processed?
    src, srcset = @photoblog.placeholder_srcset(srcset: srcset, opts: { ar: aspect_ratio })
    html_options.reverse_merge!({
      srcset: srcset,
      src: src,
      sizes: sizes,
      width: @photoblog.placeholder.metadata[:width],
      height: aspect_ratio.present? ? @photoblog.placeholder_height_from_aspect_ratio(aspect_ratio) : @photoblog.placeholder.metadata[:height],
      alt: '',
      loading: 'eager'
    }.compact)
    tag :img, html_options
  end

  def inline_svg(icon, class_name: '', aria_hidden: true)
    render partial: "partials/svg/#{icon.to_s}", locals: { class_name: "#{class_name} #{class_name}--#{icon}".strip, aria_hidden: aria_hidden }
  end

  def css_gradient_stops(photo)
    return '' if photo.color_palette.blank?
    palette = photo.color_palette.split(',').sample(2)
    "--gradient-start:#{palette.first};--gradient-end:#{palette.last};".html_safe
  end

  def css_aspect_ratio(photo)
    if photo.processed?
      "--aspect-ratio:#{(photo.height.to_f/photo.width.to_f).floor(2)};"
    elsif @photoblog.placeholder_processed?
      "--aspect-ratio:#{@photoblog.placeholder_aspect_ratio};"
    end
  end

  def blurhash_background(photo)
    if photo.blurhash.present?
      "--blurhash:url('#{blurhash_svg(photo)}');"
    elsif photo.color_palette.present?
      "--blurhash:#{photo.color_palette.split(',').sample}"
    else
      ''
    end
  end

  # Embed the Blurhash image in an SVG with a blur filter
  # https://css-tricks.com/the-blur-up-technique-for-loading-background-images/#recreating-the-blur-filter-with-svg
  def blurhash_svg(photo)
    svg = <<-SVG
      <svg xmlns="http://www.w3.org/2000/svg"
          xmlns:xlink="http://www.w3.org/1999/xlink"
          width="#{photo.width}" height="#{photo.height}"
          viewBox="0 0 #{photo.width} #{photo.height}">
        <filter id="blur" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB">
          <feGaussianBlur stdDeviation="100" edgeMode="duplicate" />
          <feComponentTransfer>
            <feFuncA type="discrete" tableValues="1 1" />
          </feComponentTransfer>
        </filter>
        <image filter="url(#blur)"
              xlink:href="#{photo.blurhash_data_uri}"
              x="0" y="0"
              height="100%" width="100%"/>
      </svg>
    SVG
    "data:image/svg+xml;charset=utf-8,#{u svg.gsub(/\s+/, ' ')}"
  end

  def css_dimensions(photo)
    if photo.processed?
      "--photo-height:#{photo.height};--photo-width:#{photo.width}"
    elsif @photoblog.placeholder_processed?
      "--photo-height:#{@photoblog.placeholder.metadata[:height]};--photo-width:#{@photoblog.placeholder.metadata[:width]}"
    end
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
