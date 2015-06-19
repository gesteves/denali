module ApplicationHelper

  def responsive_image_tag(photo, widths = [], sizes = '100vw', image_options = {}, html_options = {})
    image_options.reverse_merge! square: false, quality: 90, upscale: false
    html_options.reverse_merge! alt: photo.caption.blank? ? photo.entry.title : photo.plain_caption
    html_options[:sizes] = sizes
    srcset = []
    if image_options[:square]
      widths.each do |w|
        srcset << "#{photo.url(w, w, image_options[:quality], image_options[:upscale], true)} #{w}w"
      end
    else
      widths.each do |w|
        srcset << "#{photo.url(w, 0, image_options[:quality], image_options[:upscale])} #{w}w"
      end
    end
    html_options[:srcset] = srcset.join(', ')
    content_tag :img, nil, html_options
  end

  def get_srcset(photo_type)
    PHOTO_SIZES[photo_type].sort.uniq
  end

  def copyright_years
    current_year = Time.now.strftime('%Y')
    first_entry = Entry.published.last
    first_entry.nil? ? current_year : "#{first_entry.published_at.strftime('%Y')}-#{current_year}"
  end
end
