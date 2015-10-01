module ApplicationHelper

  def responsive_image_tag(photo, photo_key, html_options = {})
    html_options[:srcset] = get_srcset(photo, photo_key)
    html_options[:sizes] = get_sizes(photo_key)
    image_tag nil, html_options
  end

  def lazy_responsive_image_tag(photo, photo_key, html_options = {})
    html_options[:'data-srcset'] = get_srcset(photo, photo_key)
    html_options[:sizes] = get_sizes(photo_key)
    content = image_tag nil, html_options
    content += content_tag :noscript do
      image_tag get_src(photo, photo_key)
    end
  end

  def get_src(photo, photo_key)
    quality = PHOTOS[photo_key]['quality'] || 90
    square = PHOTOS[photo_key]['square'].present?
    width = PHOTOS[photo_key]['src']
    build_imgix_url(photo, width, quality, square)
  end

  def get_srcset(photo, photo_key)
    quality = PHOTOS[photo_key]['quality'] || 90
    square = PHOTOS[photo_key]['square'].present?
    PHOTOS[photo_key]['srcset'].
      uniq.
      sort.
      map { |width| "#{build_imgix_url(photo, width, quality, square)} #{width}w" }.
      join(', ')
  end

  def build_imgix_url(photo, width, quality, square)
    imgix_path = Ix.path(photo.original_path).auto('format').q(quality)
    if square
      imgix_path.fit = 'crop'
      imgix_path.crop = photo.crop unless photo.crop.blank?
      imgix_path.height = width
    else
      imgix_path.fit = 'max'
    end
    imgix_path.width(width)
    imgix_path.to_url
  end

  def get_sizes(photo_key)
    PHOTOS[photo_key]['sizes'].join(', ')
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
      canonicalUrl: permalink_url(entry)
    }

    params[:caption] = entry.formatted_body unless entry.body.blank?
    params[:tags] = entry.tag_list.join(',') unless entry.tag_list.blank?

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
