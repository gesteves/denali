module ApplicationHelper

  def responsive_image_tag(photo, photo_key, html_options = {})
    html_options[:srcset] = get_srcset(photo, photo_key)
    html_options[:sizes] = get_sizes(photo_key)
    html_options[:src] = get_src(photo, photo_key) unless PHOTOS[photo_key]['src'].nil?
    content_tag :img, nil, html_options
  end

  def lazy_responsive_image_tag(photo, photo_key, html_options = {})
    html_options[:'data-srcset'] = get_srcset(photo, photo_key)
    html_options[:sizes] = get_sizes(photo_key)
    html_options[:class] += ' js-lazy-load'
    html_options[:'data-src'] = get_src(photo, photo_key) unless PHOTOS[photo_key]['src'].nil?
    content_tag :img, nil, html_options
  end

  def amp_image_tag(photo, photo_key, html_options = {})
    html_options[:srcset] = get_srcset(photo, photo_key)
    html_options[:sizes] = get_sizes(photo_key)
    html_options[:src] = get_src(photo, photo_key) unless PHOTOS[photo_key]['src'].nil?
    content_tag 'amp-img', nil, html_options
  end

  def get_src(photo, photo_key)
    quality = PHOTOS[photo_key]['quality']
    square = PHOTOS[photo_key]['square'].present?
    width = PHOTOS[photo_key]['src']
    client_hints = PHOTOS[photo_key]['client_hints']
    auto = PHOTOS[photo_key]['auto'] || 'format'
    photo.url(w: width, q: quality, square: square, ch: client_hints, auto: auto)
  end

  def get_srcset(photo, photo_key)
    quality = PHOTOS[photo_key]['quality']
    square = PHOTOS[photo_key]['square'].present?
    client_hints = PHOTOS[photo_key]['client_hints']
    auto = PHOTOS[photo_key]['auto'] || 'format'
    PHOTOS[photo_key]['srcset'].
      uniq.
      sort.
      reject { |width| width > photo.width }.
      map { |width| "#{photo.url(w: width, q: quality, square: square, ch: client_hints, auto: auto)} #{width}w" }.
      join(', ')
  end

  def get_sizes(photo_key)
    PHOTOS[photo_key]['sizes'].join(', ')
  end

  def inline_svg(svg_id, svg_class = "icon")
    svg_id = svg_id.gsub("#", "")
    "<svg viewBox=\"0 0 100 100\" class=\"#{svg_class} #{svg_class}--#{svg_id}\"><use xlink:href=\"#svg-#{svg_id}\"></use></svg>".html_safe
  end

  def aspect_ratio(photo)
    padding = (photo.height.to_f/photo.width.to_f) * 100
    "style=padding-top:#{padding}%"
  end

  def facebook_share_url(entry)
    params = {
      u: entry.permalink_url
    }

    "https://www.facebook.com/sharer/sharer.php?#{params.to_query}"
  end

  def twitter_share_url(entry)
    params = {
      text: entry.tweet_text.blank? ? truncate(entry.plain_title, length: 120, omission: '…') : entry.tweet_text,
      url: entry.permalink_url,
      via: 'gesteves'
    }

    "https://twitter.com/intent/tweet?#{params.to_query}"
  end

  def tumblr_share_url(entry)
    params = {
      posttype: 'link',
      title: entry.plain_title,
      content: entry.permalink_url,
      canonicalUrl: entry.permalink_url
    }

    params[:tags] = entry.tag_list.join(',') unless entry.tag_list.blank?

    "https://www.tumblr.com/widgets/share/tool?#{params.to_query}"
  end

  def pinterest_share_url(entry)
    params = {
      url: entry.permalink_url,
      media: entry.photos.first.url(w: 2560),
      description: entry.plain_title
    }

    "https://www.pinterest.com/pin/create/button/?#{params.to_query}"
  end
end
