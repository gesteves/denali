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
    "#{make} #{model.gsub(%r{#{make}}i, '')}"
  end

  def article(word)
    %w(a e i o u).include?(word[0].downcase) ? 'an' : 'a'
  end

  def atom_tag(url, date)
    tag = url.gsub(/^http(s)?:\/\//, '').gsub('#', '/').split('/')
    tag[0] = "tag:#{tag[0]},#{date.strftime('%Y-%m-%d')}:"
    tag.join('/')
  end

  def entry_color(entry)
    if entry.is_photo?
      color = entry.photos.first.dominant_color || '#f4f4f4'
      "style=background-color:#{color};"
    end
  end
end
