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
      if entry.body.present?
        entry.plain_body
      elsif entry.photos.first.caption.present?
        entry.photos.first.plain_caption
      else
        Sanitize.fragment(entry.blog.description)
      end
    else
      entry.plain_body
    end
    truncate body, length: 200
  end

  def get_rss_widths(photo, photo_key)
    PHOTOS[photo_key]['srcset'].uniq.sort.reject { |width| width > photo.width }
  end
end
