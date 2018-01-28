module EntriesHelper
  def aperture(f_number)
    "%g" % ("%.2f" % f_number)
  end

  def exposure(exposure)
    exposure = exposure.to_r
    formatted = exposure >= 1 ? "%g" % ("%.2f" % exposure) : exposure
    "#{formatted}″"
  end

  def article(word)
    %w(a e i o u).include?(word[0].downcase) ? 'an' : 'a'
  end

  def atom_tag(url, date)
    tag = url.gsub(/^http(s)?:\/\//, '').gsub('#', '/').split('/')
    tag[0] = "tag:#{tag[0]},#{date.strftime('%Y-%m-%d')}:"
    tag.join('/')
  end

  def meta_description(entry)
    body = if entry.is_photo?
      if entry.photos.first.caption.present?
        entry.photos.first.plain_caption
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

  def plain_exif(photo)
    fields = []
    if photo.make.present? && photo.model.present?
      camera = "Taken with #{article photo.make} #{photo.formatted_camera}"
      if photo.is_film?
        camera += "on #{photo.formatted_film}"
      end
      fields << camera

      unless photo.is_phone_camera?
        fields << "#{photo.focal_length} mm focal length"
        if photo.exposure.present? && photo.f_number.present?
          fields << "#{exposure photo.exposure} at f/#{aperture photo.f_number}"
        elsif photo.exposure.present?
          fields << exposure(photo.exposure)
        elsif photo.f_number.present?
          fields << "f/#{aperture photo.f_number}"
        end
        if photo.iso.present?
          fields << "ISO #{photo.iso}"
        end
      end
    end
    fields.join(' · ')
  end
end
