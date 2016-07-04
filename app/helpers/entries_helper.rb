module EntriesHelper
  def aperture(f_number)
    "%g" % ("%.2f" % f_number)
  end

  def exposure(exposure)
    exposure = exposure.to_r
    formatted = exposure >= 1 ? "%g" % ("%.2f" % exposure) : exposure
    unit = exposure == 1 ? 'second' : 'seconds'
    "#{formatted} #{unit}"
  end

  def film(make, model)
    model.match(make) ? model : "#{make} #{model}"
  end

  def camera(make, model)
    make = if make =~ /olympus/i
      'Olympus'
    elsif make =~ /nikon/i
      'Nikon'
    elsif make =~ /fuji/i
      'Fujifilm'
    elsif make =~ /canon/i
      'Canon'
    end
    if make
      "#{make} #{model.gsub(%r{#{make}}i, '')}"
    end
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
end
