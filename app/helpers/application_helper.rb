module ApplicationHelper

  def responsive_image_tag(photo, photo_key, html_options = {})
    html_options.reverse_merge! alt: photo.caption.blank? ? photo.entry.title : photo.plain_caption
    html_options[:srcset] = get_srcset(photo, photo_key)
    html_options[:sizes] = get_sizes(photo_key)
    content_tag :img, nil, html_options
  end


  def get_srcset(photo, photo_key)
    filters = get_filters(photo_key)
    PHOTOS[photo_key]['srcset'].
      uniq.
      sort{ |a, b| a.split('x').first.to_i <=> b.split('x').first.to_i }.
      map{ |s| build_srcset_url(photo, s, filters)}.
      join(', ')
  end

  def build_srcset_url(photo, dimensions, filters)
    width = dimensions.split('x').first.to_i
    height = dimensions.split('x').last.to_i
    "#{photo.url(width, height, filters)} #{width}w"
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
