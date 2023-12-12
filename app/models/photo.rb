require 'mini_magick'
class Photo < ApplicationRecord
  include Thumborizable

  belongs_to :entry, touch: true, counter_cache: true, optional: true
  belongs_to :camera, optional: true
  belongs_to :lens, optional: true
  belongs_to :film, optional: true
  belongs_to :park, optional: true
  has_one_attached :image
  has_one :profile
  has_many :crops, dependent: :destroy

  acts_as_list scope: :entry

  after_create_commit :extract_metadata, :detect_colors, :encode_blurhash

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
    opts[:crop] = calculate_crop(opts) unless opts[:fit_in]
    thumbor_url(self.image.key, opts.compact)
  end

  def srcset(srcset:, src: nil, opts: {})
    widths = has_dimensions? ? srcset.reject { |width| width > self.width } : srcset
    widths = widths.uniq.sort
    src_width = src || widths.first

    opts[:crop] = calculate_crop(opts) unless opts[:fit_in]
    src = thumbor_url(self.image.key, opts.merge(width: src_width).compact)
    srcset = widths.map { |w| "#{thumbor_url(self.image.key, opts.merge(width: w).compact)} #{w}w" }.join(', ')
    return src, srcset
  end

  def calculate_crop(opts)
    return opts[:crop] if opts[:crop].present?
    if crop = self.crop(opts[:aspect_ratio])&.to_rect
      crop
    elsif opts[:aspect_ratio].present?
      aspect_ratio_to_crop(opts[:aspect_ratio])
    elsif opts[:width].present? && opts[:height].present? && opts[:height] != height_from_width(opts[:width])
      aspect_ratio_to_crop("#{opts[:width]}:#{opts[:height]}")
    else
      nil
    end
  end

  def aspect_ratio_to_crop(aspect_ratio)
    aspect_ratio_parts = aspect_ratio.split(':').map(&:to_f)
    target_aspect_ratio = aspect_ratio_parts[0] / aspect_ratio_parts[1]

    # Default focal point to the center of the image if not provided
    x_focal = self.focal_x || 0.5
    y_focal = self.focal_y || 0.5

    current_aspect_ratio = self.width.to_f / self.height.to_f

    if current_aspect_ratio > target_aspect_ratio
      new_width = target_aspect_ratio * self.height
      new_height = self.height
    else
      new_width = self.width
      new_height = self.width / target_aspect_ratio
    end

    left = (self.width - new_width) * x_focal
    top = (self.height - new_height) * y_focal
    right = left + new_width
    bottom = top + new_height

    [left, top, right, bottom].map(&:round)
  end

  # Returns the url of the image, formatted & sized to fit into instagram's
  # 5:4 ratio
  def instagram_url
    opts = { fit_in: true, fill: 'fff', quality: 100, format: 'jpeg' }

    new_url = if self.is_vertical?
      width, height = 1080, 1350
      self.url(opts.merge(width: width, height: (height - 100)))
    else
      width, height = 1080, 1080
      self.url(opts.merge(width: (width - 100), height: height))
    end

    thumbor_url(new_url, opts.merge(width: width, height: height))
  end

  # Returns the url of the image, formatted & sized to fit into instagram stories'
  # 16:9 ratio
  def instagram_story_url(crop: false)
    opts = if crop
      { width: 2160, aspect_ratio: '9:16', quality: 100, format: 'jpeg' }
    else
      { width: 2160, height: 3840, fit_in: true, fill: '000', quality: 100, format: 'jpeg' }
    end
    self.url(opts)
  end

  def facebook_card_url
    self.url(width: 1200, format: 'jpeg', aspect_ratio: '1200:630')
  end

  def mastodon_url
    opts = { width: 2560, format: 'jpeg' }
    self.url(opts)
  end

  def tumblr_url
    opts = { width: 2048, format: 'jpeg' }
    self.url(opts)
  end

  def bluesky_url
    width = self.is_vertical? ? width_from_height(2000) : 2000
    opts = { width: width, format: 'jpeg', quality: 60 }
    self.url(opts)
  end

  def iphone_wallpaper_url
    opts = { aspect_ratio: '9:19.5' }
    self.url(opts)
  end

  def crop(aspect_ratio)
    return if aspect_ratio.blank?
    self.crops.find_by(aspect_ratio: aspect_ratio)
  end

  # Focal points are stored as a [0,1] range,
  # but Mastodon expects a [-1,1] range.
  def mastodon_focal_point
    return [] if focal_x.blank? || focal_y.blank?

    focal_x_transformed = ((focal_x * 2) - 1).round(3)
    focal_y_transformed = (1 - (focal_y * 2)).round(3)

    [focal_x_transformed, focal_y_transformed]
  end

  def has_dimensions?
    self.width.present? && self.height.present?
  end

  def width
    image&.metadata&.dig(:width)
  end

  def height
    image&.metadata&.dig(:height)
  end

  def is_square?
    return false unless has_dimensions?
    width == height
  end

  def is_horizontal?
    return false unless has_dimensions?
    width > height
  end

  def is_vertical?
    return false unless has_dimensions?
    width < height
  end

  def has_location?
    self.longitude.present? && self.latitude.present?
  end

  def height_from_width(width)
    return unless has_dimensions?
    ((self.height.to_f * width.to_f)/self.width.to_f).round
  end

  def width_from_height(height)
    return unless has_dimensions?
    ((self.width.to_f * height.to_f)/self.height.to_f).round
  end

  def height_from_aspect_ratio(aspect_ratio)
    return unless has_dimensions?
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
    text.join(' – ')
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

    location = []
    location << self.formatted_location if self.formatted_location.present?
    location << "#{self.territory_list} land" if self.territory_list.present?

    meta = []
    meta << "📷 #{camera_film.join(' + ')}" if camera_film.present?
    meta << "ℹ️ #{self.formatted_exif}" if self.formatted_exif.present? && self.film.blank?
    meta << "📍 #{location.join(' – ')}" if location.present? && self.entry.show_location?
    meta << "🔗 <a href=\"#{self.entry.permalink_url}\">#{self.entry.permalink_url.gsub(/https?:\/\//, '')}</a>"

    text = []
    text << self.entry.plain_body
    text << meta.join("\n")
    text.reject(&:blank?).join("\n\n")
  end

  def reddit_caption
    camera_film = []
    camera_film << self.formatted_camera if self.formatted_camera.present?
    camera_film << self.film.display_name if self.film.present?

    location = []
    location << self.formatted_location if self.formatted_location.present?
    location << "#{self.territory_list} land" if self.territory_list.present?

    meta = []
    meta << "📷 #{camera_film.join(' + ')}" if camera_film.present?
    meta << "🎞 #{self.formatted_exif}" if self.formatted_exif.present? && self.film.blank?
    meta << "📍 #{location.join(' – ')}" if location.present? && self.entry.show_location?
    meta << "🔗 [#{self.entry.permalink_url.gsub(/https?:\/\/(www\.)?/, '')}](#{self.entry.permalink_url})"

    text = []
    text << self.alt_text
    text << meta.join("  \n")
    text.reject(&:blank?).join("\n\n")
  end

  def flickr_tags
    self.entry.combined_tag_list.map { |t| "\"#{t.gsub(/["']/, '')}\"" }.join(' ')
  end

  def plain_metadata
    location = []
    location << self.formatted_location if self.formatted_location.present?
    location << "#{self.territory_list} land" if self.territory_list.present?

    meta = []
    meta << "📷 #{self.formatted_camera}" if self.formatted_camera.present?
    meta << "🎞 #{self.formatted_exif}" if self.formatted_exif.present? && self.film.blank?
    meta << "🎞 #{self.film.display_name}" if self.film.present?
    meta << "📍 #{location.join(' – ')}" if location.present? && self.entry.show_location?
    meta << "🔗 #{self.entry.permalink_url}"
    meta.join("\n")
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

  def detect_colors
    ColorDetectionWorker.perform_async(self.id)
  end

  def encode_blurhash
    BlurhashWorker.perform_async(self.id)
  end

  def update_park
    NationalParkWorker.perform_async(self.id)
  end

  def blurhash_data_uri(w: 32)
    return unless self.has_dimensions? && Blurhash.valid_blurhash?(self.blurhash)
    h = self.height_from_width(w)
    Rails.cache.fetch("blurhash-data-uri/#{self.blurhash}/w/#{w}/h/#{h}") do
      pixels = Blurhash.decode(w, h, self.blurhash)
      depth = 8
      dimensions = [w, h]
      map = 'rgba'
      image = MiniMagick::Image.get_image_from_pixels(pixels, dimensions, map, depth, 'jpg')
      "data:image/jpeg;base64,#{Base64.strict_encode64(image.to_blob)}"
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
