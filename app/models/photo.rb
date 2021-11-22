class Photo < ApplicationRecord
  belongs_to :entry, touch: true, counter_cache: true, optional: true
  belongs_to :camera, optional: true
  belongs_to :lens, optional: true
  belongs_to :film, optional: true
  belongs_to :park, optional: true
  has_one_attached :image

  acts_as_list scope: :entry

  after_create_commit :extract_metadata, :annotate, :encode_blurhash

  after_commit :touch_entry
  after_commit :geocode, if: :changed_coordinates?
  after_commit :update_native_lands, if: :changed_coordinates?
  after_commit :update_entry_equipment_tags, if: :changed_equipment?
  after_commit :update_entry_location_tags, if: :changed_location?
  after_commit :update_entry_style_tags, if: :changed_style?
  after_commit :update_park, if: :changed_location?

  def touch_entry
    self.entry&.touch
  end

  def update_entry_equipment_tags
    self.entry.update_equipment_tags
  end

  def update_entry_location_tags
    self.entry.update_location_tags
  end

  def update_entry_style_tags
    self.entry.update_style_tags
  end

  def self.oldest
    order('taken_at ASC').limit(1)&.first
  end

  def url(opts = {})
    opts.reverse_merge!(w: 1200)
    if opts[:ar].present? || (opts[:w].present? && opts[:h].present? && opts[:h] != height_from_width(opts[:w]))
      opts.reverse_merge!(fit: 'crop')
      opts.merge!(crop: 'focalpoint', 'fp-x': self.focal_x, 'fp-y': self.focal_y) if self.focal_x.present? && self.focal_y.present?
    end
    Ix.path(self.image.key).to_url(opts.compact)
  end

  def srcset(srcset:, opts: {})
    opts.reverse_merge!(q: 75)
    imgix_path = Ix.path(self.image.key)
    widths = processed? ? srcset.reject { |width| width > self.width } : srcset
    widths = widths.uniq.sort
    src_width = widths.first
    if opts[:ar].present? || (opts[:w].present? && opts[:h].present? && opts[:h] != height_from_width(opts[:w]))
      opts.reverse_merge!(fit: 'crop')
      opts.merge!(crop: 'focalpoint', 'fp-x': self.focal_x, 'fp-y': self.focal_y) if self.focal_x.present? && self.focal_y.present?
    end
    src = imgix_path.to_url(opts.merge(w: src_width).compact)
      srcset = widths.map { |w| "#{imgix_path.to_url(opts.merge(w: w).compact)} #{w}w" }.join(', ')
    return src, srcset
  end

  # Returns the url of the image, formatted & sized to fit into instagram's
  # 5:4 ratio
  def instagram_url
    opts = { w: 1080, fit: 'fill', bg: 'fff', pad: 50, q: 90, fm: 'jpg' }
    opts[:h] = self.is_vertical? ? 1350 : 1080
    self.url(opts)
  end

  # Returns the url of the image, formatted & sized to fit into instagram stories'
  # 16:9 ratio
  def instagram_story_url
    self.url(w: 2160, h: 3840, fit: 'fill', fill: 'blur', q: 90, fm: 'jpg')
  end

  # Returns the url of the image, formatted & sized for twitter
  def twitter_url
    max_width = PHOTOS[:entry][:srcset].max
    opts = { fm: 'jpg' }
    opts[:w] = if self.is_vertical?
      [self.width, self.width_from_height(max_width)].min
    else
      [self.width, max_width].min
    end
    self.url(opts)
  end

  def facebook_card_url
    self.url(w: 1200, h: 630)
  end

  def twitter_card_url
    self.url(w: 1200, h: 600)
  end

  def blurhash_url(opts = {})
    opts.reverse_merge!(fm: 'blurhash', w: 32)
    Ix.path(self.image.key).to_url(opts)
  end

  def purge
    url = Ix.path(self.image.key).to_url
    uri = URI.parse(url)
    Ix.purge(uri.path)
  end

  def processed?
    image&.attached? && image&.analyzed? && image&.identified?
  end

  def width
    image.metadata[:width]
  end

  def height
    image.metadata[:height]
  end

  def is_square?
    return false unless processed?
    width == height
  end

  def is_horizontal?
    return false unless processed?
    width > height
  end

  def is_vertical?
    return false unless processed?
    width < height
  end

  def has_location?
    self.longitude.present? && self.latitude.present?
  end

  def height_from_width(width)
    return nil if self.width.blank?
    ((self.height.to_f * width.to_f)/self.width.to_f).round
  end

  def width_from_height(height)
    return nil if self.height.blank?
    ((self.width.to_f * height.to_f)/self.height.to_f).round
  end

  def height_from_aspect_ratio(aspect_ratio)
    return nil if self.width.blank?
    ar = aspect_ratio.split(':').map(&:to_f)
    ((self.width.to_f * ar.last)/ar.first).round
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
    exp = self.exposure.to_r.rationalize
    formatted = exp >= 1 ? "%g" % ("%.2f" % exp) : exp.to_s
    "#{formatted}″"
  end

  def formatted_exif
    text = []
    text << self.focal_length_with_unit if self.focal_length.present?
    text << self.formatted_exposure if self.exposure.present?
    text << self.formatted_aperture if self.f_number.present?
    text << "ISO #{self.iso}" if self.iso.present?
    text.join(' • ')
  end

  def formatted_camera
    return if self.camera.blank? && self.lens.blank?
    camera = []
    camera << self.camera.display_name if self.camera.present?
    camera << self.lens.display_name if self.lens.present? && !self.camera&.is_phone?
    camera.join(' + ')
  end

  def formatted_location
    if self.park.present?
      [self.park.display_name, self.administrative_area, self.country].reject(&:blank?).uniq.join(', ')
    elsif self.location.present?
      [self.location, self.administrative_area, self.country].reject(&:blank?).uniq.join(', ')
    else
      [self.locality, self.administrative_area, self.country].reject(&:blank?).uniq.join(', ')
    end
  end

  def territory_list
    return unless self.territories.present?
    parsed_list = JSON.parse(self.territories)

    territory_list = if parsed_list.size > 2
      temporary_list = parsed_list
      last = temporary_list.pop
      "#{temporary_list.join(', ')}, and #{last}"
    else
      parsed_list.join(' and ')
    end

    territory_list
  end

  def flickr_caption
    camera_film = []
    camera_film << self.formatted_camera if self.formatted_camera.present?
    camera_film << self.film.display_name if self.film.present?

    meta = []
    meta << "📷 #{camera_film.join(' + ')}" if camera_film.present?
    meta << "ℹ️ #{self.formatted_exif}" if self.formatted_exif.present? && self.film.blank?
    meta << "📍 #{self.territory_list} land" if self.entry.show_location? && self.territory_list.present?
    meta << "🔗 #{self.entry.permalink_url}"

    text = []
    text << self.entry.plain_body
    text << meta.join("\n")
    text.reject(&:blank?).join("\n\n")
  end

  def extract_metadata
    PhotoExifWorker.perform_async(self.id)
  end

  def geocode
    PhotoGeocodeWorker.perform_async(self.id)
  end

  def update_native_lands
    NativeLandsWorker.perform_async(self.id)
  end

  def annotate
    GoogleVisionWorker.perform_async(self.id)
  end

  def encode_blurhash
    BlurhashWorker.perform_async(self.id)
  end

  def update_park
    NationalParkWorker.perform_async(self.id)
  end

  def blurhash_data_uri(w: 32)
    return unless self.processed?
    h = self.height_from_width(w)
    Rails.cache.fetch("blurhash-data-uri/#{self.blurhash}/w/#{w}/h/#{h}") do
      Blurhash.to_data_uri(blurhash: self.blurhash, w: w, h: h)
    end
  end

  def changed_dimensions?
    saved_change_to_width? || saved_change_to_height?
  end

  def changed_coordinates?
    saved_change_to_latitude? || saved_change_to_longitude?
  end

  def changed_equipment?
    saved_change_to_camera_id? || saved_change_to_film_id? || saved_change_to_lens_id?
  end

  def changed_location?
    saved_change_to_country? ||
    saved_change_to_locality? ||
    saved_change_to_sublocality? ||
    saved_change_to_neighborhood? ||
    saved_change_to_administrative_area? ||
    saved_change_to_postal_code? ||
    saved_change_to_location? ||
    saved_change_to_park_id?
  end

  def changed_style?
    saved_change_to_color? || saved_change_to_black_and_white? || saved_change_to_camera_id? || saved_change_to_film_id?
  end
end
