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

  def inline_svg(svg_id, svg_class = "icon")
    svg_id = svg_id.gsub("#", "")
    "<svg viewBox=\"0 0 100 100\" class=\"#{svg_class} #{svg_class}--#{svg_id}\"><use xlink:href=\"#svg-#{svg_id}\"></use></svg>".html_safe
  end

  def facebook_share_url(entry)
    params = {
      u: permalink_url(entry)
    }

    "https://www.facebook.com/sharer/sharer.php?#{params.to_query}"
  end

  def twitter_share_url(entry)
    params = {
      text: entry.tweet_text.blank? ? truncate(entry.formatted_title, length: 120, omission: '…') : entry.tweet_text,
      url: permalink_url(entry),
      via: 'gesteves'
    }

    "https://twitter.com/intent/tweet?#{params.to_query}"
  end

  def tumblr_share_url(entry)
    params = {
      posttype: 'link',
      title: entry.formatted_title,
      content: permalink_url(entry),
      caption: entry.formatted_body,
      tags: entry.tag_list.join(',')
    }

    "https://www.tumblr.com/widgets/share/tool?#{params.to_query}"
  end

  def pinterest_share_url(entry)
    params = {
      url: permalink_url(entry),
      media: entry.photos.first.url(2560),
      description: entry.formatted_title
    }

    "https://www.pinterest.com/pin/create/button/?#{params.to_query}"
  end
end
