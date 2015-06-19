module ApplicationHelper

  def responsive_image_tag(photo, photo_key, image_options = {}, html_options = {})
    html_options.reverse_merge! alt: photo.caption.blank? ? photo.entry.title : photo.plain_caption
    image_options.reverse_merge! quality: 90
    html_options[:srcset] = get_srcset(photo, photo_key, image_options[:quality])
    html_options[:sizes] = get_sizes(photo_key)
    content_tag :img, nil, html_options
  end


  def get_srcset(photo, photo_key, quality)
    srcset = []
    filters = ["quality(#{quality})"] + get_filters(photo_key)
    PHOTOS[photo_key]['srcset'].uniq.sort{ |a,b| a.split('x').first.to_i <=> b.split('x').first.to_i }.each do |s|
      width = s.split('x').first.to_i
      height = s.split('x').last.to_i
      srcset << "#{photo.url(width, height, filters)} #{width}w"
    end
    srcset.join(', ')
  end

  def get_sizes(photo_key)
    PHOTOS[photo_key]['sizes'].join(', ')
  end

  def get_filters(photo_key)
    filters = []
    filters << PHOTOS[photo_key]['filters'] unless PHOTOS[photo_key]['filters'].nil?
    filters
  end

  def copyright_years
    current_year = Time.now.strftime('%Y')
    first_entry = Entry.published.last
    first_entry.nil? ? current_year : "#{first_entry.published_at.strftime('%Y')}-#{current_year}"
  end
end
