module ApplicationHelper

  def responsive_image_tag(photo, widths = [], sizes = '100vw', image_options = {}, html_options = {})
    image_options.reverse_merge! square: false, quality: 90, upscale: false
    html_options.reverse_merge! alt: photo.caption.blank? ? photo.entry.title : photo.plain_caption
    html_options[:sizes] = sizes unless sizes == ''
    srcset = []
    if image_options[:square]
      widths.each do |w|
        srcset << "#{photo.url(w, w, image_options[:quality], image_options[:upscale], true)} #{w}w"
      end
      html_options[:srcset] = srcset.join(', ')
      html_options[:src] = photo.url(image_options[:default_width], image_options[:default_width], image_options[:quality], image_options[:upscale]) if image_options[:default_width].present?
    else
      widths.each do |w|
        srcset << "#{photo.url(w, 0, image_options[:quality], image_options[:upscale])} #{w}w"
      end
      html_options[:srcset] = srcset.join(', ')
      html_options[:src] = photo.url(image_options[:default_width], 0, image_options[:quality], image_options[:upscale]) if image_options[:default_width].present?
    end
    content_tag :img, nil, html_options
  end

  def get_srcset(photo_type)
    PHOTO_SIZES[photo_type].sort.uniq
  end

  def copyright_years
    if Entry.published.last.nil?
      Time.now.strftime('%Y')
    elsif Entry.published.last.published_at.strftime('%Y') == Time.now.strftime('%Y')
      Time.now.strftime('%Y')
    else
      "#{Entry.published.last.published_at.strftime('%Y')}-#{Time.now.strftime('%Y')}"
    end
  end
end
