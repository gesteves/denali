module EntriesHelper
  def atom_tag(url, date)
    tag = url.gsub(/^http(s)?:\/\//, '').gsub('#', '/').split('/')
    tag[0] = "tag:#{tag[0]},#{date.strftime('%Y-%m-%d')}:"
    tag.join('/')
  end

  def entry_photo_widths(photo, key)
    PHOTOS[key]['srcset'].uniq.sort.reject { |width| width > photo.width }
  end

  def schema_photo_src(photo)
    src, srcset = photo.srcset(srcset: PHOTOS[:entry][:srcset], src: PHOTOS[:entry][:src])
    src
  end

  def exif_for_feeds(photo, separator: ' – ')
    exif = []
    exif << "#{photo.focal_length_with_unit} focal length" if photo.focal_length.present?
    if photo.exposure.present? && photo.f_number.present?
      exif << "#{photo.formatted_exposure} at #{photo.formatted_aperture}"
    elsif photo.exposure.present?
      exif << photo.formatted_aperture
    elsif photo.f_number.present?
      exif << photo.formatted_aperture
    end
    exif << "ISO #{photo.iso}"
    exif.join(separator)
  end
end
