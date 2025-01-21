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

  # Generates a paragraph with camera, lens, and film details
  def feed_camera_details(photo)
    return if photo.camera.blank?

    details = []
    details << "Photographed with #{photo.camera.article} #{photo.camera.display_name}"
    details << "+ #{photo.lens.display_name}" if photo.lens.present? && !photo.camera.is_phone?
    details << "on #{photo.film.display_name}" if photo.film.present?

    "📷 #{details.join(' ')}<br>".html_safe
  end

  # Generates a paragraph with EXIF details like focal length, exposure, aperture, and ISO
  def feed_exif(photo)
    return if photo.film.present?

    details = []
    details << "#{photo.focal_length_with_unit} focal length" if photo.focal_length.present?
    if photo.exposure.present? && photo.f_number.present?
      details << "#{photo.formatted_exposure} at #{photo.formatted_aperture}"
    elsif photo.exposure.present?
      details << photo.formatted_exposure
    elsif photo.f_number.present?
      details << photo.formatted_aperture
    end
    details << "ISO #{photo.iso}" if photo.iso.present?

    "🎞️ #{details.join(' – ')}<br>".html_safe
  end

  # Generates a paragraph with location and territories details
  def feed_location(photo)
    return if photo.formatted_location.blank? && photo.territories.blank?

    details = []
    details << photo.formatted_location if photo.formatted_location.present?
    details << "#{photo.territory_list} land" if photo.territories.present?

    "📍 #{details.join(' – ')}".html_safe
  end
end
