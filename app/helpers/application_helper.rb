module ApplicationHelper

  def responsive_image_tag(photo, widths = [], sizes = '100vw', image_options = {}, html_options = {})
    image_options.reverse_merge! square: false, quality: 90, default_width: 1280, default_height: 0, upscale: false
    html_options.reverse_merge! alt: photo.plain_caption || photo.entry.title
    html_options[:sizes] = sizes unless sizes == ''
    srcset = []
    if image_options[:square]
      widths.each do |w|
        srcset << "#{photo.url(w, w, image_options[:quality], image_options[:upscale])} #{w}w"
      end
      html_options[:srcset] = srcset.join(', ')
      src = photo.url(image_options[:default_width], image_options[:default_width], image_options[:quality], image_options[:upscale])
    else
      widths.each do |w|
        srcset << "#{photo.url(w, image_options[:default_height], image_options[:quality], image_options[:upscale])} #{w}w"
      end
      html_options[:srcset] = srcset.join(', ')
      src = photo.url(image_options[:default_width], image_options[:default_height], image_options[:quality], image_options[:upscale])
    end
    image_tag src, html_options
  end

  def copyright_years
    start_year = Entry.published.last.published_at.strftime('%Y')
    end_year = Time.now.strftime('%Y')
    if start_year == end_year
      start_year
    else
      "#{start_year}–#{end_year}"
    end
  end
end
