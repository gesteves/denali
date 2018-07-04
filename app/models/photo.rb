require 'exifr/jpeg'

class Photo < ApplicationRecord
  include Formattable

  belongs_to :entry, touch: true, counter_cache: true, optional: true
  has_one_attached :image

  acts_as_list scope: :entry

  after_save :update_entry

  def update_entry
    self.entry.touch
    self.entry.update_tags
  end

  def self.oldest
    order('taken_at ASC').limit(1)&.first
  end

  def url(opts = {})
    opts.reverse_merge!(w: 1200, auto: 'format', square: false)
    if opts[:square]
      opts[:h] = opts[:w]
      opts.delete(:square)
    end
    if opts[:w].present? && opts[:h].present? && opts[:h] != height_from_width(opts[:w]) && !opts[:fit].present?
      opts[:fit] = 'crop'
      opts.merge!(crop: 'focalpoint', 'fp-x': self.focal_x, 'fp-y': self.focal_y) if self.focal_x.present? && self.focal_y.present?
    end
    if opts[:fm].present?
      opts.delete(:auto)
    end
    Ix.path(self.image.key).to_url(opts.reject { |k,v| v.blank? })
  end

  def srcset(widths, opts = {})
    opts.reverse_merge!(auto: 'format', square: false)
    square = opts[:square]
    opts.delete(:square)
    s3_key = self.image.key
    max_width = self.width
    widths = widths.uniq.sort.reject { |width| width > max_width }
    src_width = widths.last
    if square
      opts[:fit] = 'crop'
      opts.merge!(crop: 'focalpoint', 'fp-x': self.focal_x, 'fp-y': self.focal_y) if self.focal_x.present? && self.focal_y.present?
      src = Ix.path(s3_key).to_url(opts.merge(w: src_width, h: src_width))
      srcset = widths.map { |w| "#{Ix.path(s3_key).to_url(opts.merge(w: w, h: w))} #{w}w" }.join(', ')
    else
      src = Ix.path(s3_key).to_url(opts.merge(w: src_width))
      srcset = widths.map { |w| "#{Ix.path(s3_key).to_url(opts.merge(w: w))} #{w}w" }.join(', ')
    end
    return src, srcset
  end

  # Returns the url of the image, formatted & sized fit to into instagram's
  # 5:4 ratio
  def instagram_url
    if self.is_vertical?
      self.url(w: 1080, h: 1350, fit: 'fill', bg: 'fff', fm: 'jpg', q: 90)
    elsif self.is_horizontal?
      self.url(w: 1080, h: 864, fit: 'fill', bg: 'fff', fm: 'jpg', q: 90)
    else
      self.url(w: 1080, fm: 'jpg', q: 90)
    end
  end

  # Returns the url of the image, formatted & sized fit to into instagram stories'
  # 16:9 ratio
  def instagram_story_url
    self.url(w: 2160, h: 3840, fit: 'fill', bg: '000', fm: 'jpg', q: 90, pad: 100)
  end

  def palette_url(opts = {})
    opts.reverse_merge!(palette: 'json', colors: 6)
    Ix.path(self.image.key).to_url(opts)
  end

  def formatted_caption
    markdown_to_html(self.caption)
  end

  def plain_caption
    markdown_to_plaintext(self.caption)
  end

  def is_square?
    self.width == self.height
  end

  def is_horizontal?
    self.width > self.height
  end

  def is_vertical?
    self.width < self.height
  end

  def has_location?
    self.longitude.present? && self.latitude.present?
  end

  def height_from_width(width)
    ((self.height.to_f * width.to_f)/self.width.to_f).round
  end

  def width_from_height(height)
    ((self.width.to_f * height.to_f)/self.height.to_f).round
  end

  def formatted_make
    if self.make =~ /olympus/i
      'Olympus'
    elsif self.make =~ /nikon/i
      'Nikon'
    elsif self.make =~ /fuji/i
      'Fujifilm'
    elsif self.make =~ /canon/i
      'Canon'
    elsif self.make =~ /leica/i
      'Leica'
    else
      self.make&.titlecase
    end
  end

  def formatted_camera
    if self.model =~ /iphone/i
      self.model
    elsif self.model =~ /leica/i
      self.model.titlecase
    else
      "#{self.formatted_make} #{self.model&.gsub(%r{#{formatted_make}}i, '')&.strip}"
    end
  end

  def formatted_film
    return '' if self.film_type.blank? || self.film_make.blank?
    self.film_type.match(self.film_make) ? self.film_type : "#{self.film_make} #{self.film_type}"
  end

  def is_phone_camera?
    self.model =~ /iphone/i
  end

  def is_film?
    self.film_make.present? && self.film_type.present?
  end

  def taken_with
    return '' if self.formatted_camera.blank?
    article = %w(a e i o u).include?(self.formatted_camera[0].downcase) ? 'an' : 'a'
    text = "Taken with #{article} #{self.formatted_camera}"
    text += " on #{self.formatted_film}" if self.is_film?
    text
  end

  def focal_length_with_unit
    return '' if self.focal_length.blank?
    "#{self.focal_length} mm"
  end

  def formatted_aperture
    return '' if self.f_number.blank?
    f = "%g" % ("%.2f" % self.f_number)
    "f/#{f}"
  end

  def formatted_exposure
    return '' if self.exposure.blank?
    exp = self.exposure.to_r
    formatted = exp >= 1 ? "%g" % ("%.2f" % exp) : exp
    "#{formatted}″"
  end

  def exif_string(separator = ' · ')
    items = []
    items << self.taken_with

    unless self.is_phone_camera?
      items << self.focal_length_with_unit

      if self.exposure.present? && self.f_number.present?
        items << "#{self.formatted_exposure} at #{self.formatted_aperture}"
      elsif self.exposure.present?
        items << self.formatted_exposure
      elsif self.f_number.present?
        items << self.formatted_aperture
      end

      if self.iso.present?
        items << "ISO #{self.iso}"
      end
    end

    items.reject(&:blank?).join(separator)
  end

  def long_address
    [self.neighborhood, self.sublocality, self.locality, self.administrative_area, self.country].uniq.reject(&:blank?).join(', ')
  end

  def short_address
    [self.locality, self.administrative_area, self.country].uniq.reject(&:blank?).reject { |a| a.match? /^united (states|kingdom)/i }.join(', ')
  end

  def extract_metadata
    PhotoMetadataJob.perform_later(self)
  end

  def geocode
    PhotoGeocodeJob.perform_later(self)
  end

  def extract_keywords
    PhotoKeywordsJob.perform_later(self)
  end

  def extract_palette
    PhotoPaletteJob.perform_later(self)
  end

  def prominent_color
    self.color_vibrant || self.color_muted || '#EEEEEE'
  end

  def color?
    return if self.color_palette.blank?
    !self.color_palette.split(',').map { |c| c.gsub('#', '') }.reject { |c| c.scan(/../).uniq.size == 1 }.empty?
  end

  def black_and_white?
    return if self.color_palette.blank?
    !self.color?
  end

  def alt_text
    if self.caption.present?
      self.plain_caption
    elsif self.keywords.present?
      "Photo may contain: #{self.keywords}"
    else
      ''
    end
  end
end
