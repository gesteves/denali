module EntriesHelper
  def atom_tag(url, date)
    tag = url.gsub(/^http(s)?:\/\//, '').gsub('#', '/').split('/')
    tag[0] = "tag:#{tag[0]},#{date.strftime('%Y-%m-%d')}:"
    tag.join('/')
  end

  def meta_description(entry)
    body = if entry.is_photo?
      if entry.photos.first.alt_text.present?
        entry.photos.first.alt_text
      elsif entry.body.present?
        entry.plain_body
      else
        Sanitize.fragment(entry.blog.description)
      end
    else
      entry.plain_body
    end
    truncate body, length: 200
  end

  def entry_photo_widths(photo, key)
    PHOTOS[key]['srcset'].uniq.sort.reject { |width| width > photo.width }
  end

  def entry_list_image_variant(opts = {})
    opts.reverse_merge!(square: false)
    if opts[:square]
      'entry_list_square'
    else
      'entry_list'
    end
  end

  def json_schema_images(photo)
    [
      photo.url(w: 1200, h: 675, fm: 'jpg'),
      photo.url(w: 1200, h: 900, fm: 'jpg'),
      photo.url(w: 1200, square: true)
    ]
  end

  def entry_list_item_observer(url)
    "data-controller=\"pagination\" data-pagination-page-url=\"#{url}\"".html_safe
  end
end
