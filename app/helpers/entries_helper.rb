module EntriesHelper
  def atom_tag(url, date)
    tag = url.gsub(/^http(s)?:\/\//, '').gsub('#', '/').split('/')
    tag[0] = "tag:#{tag[0]},#{date.strftime('%Y-%m-%d')}:"
    tag.join('/')
  end

  def entry_photo_widths(photo, key)
    PHOTOS[key]['srcset'].uniq.sort.reject { |width| width > photo.width }
  end

  def json_schema_images(photo)
    [
      photo.url(w: 1200, h: 675, fm: 'jpg'),
      photo.url(w: 1200, h: 900, fm: 'jpg'),
      photo.url(w: 1200, square: true)
    ]
  end
end
