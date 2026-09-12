require 'mini_magick'
class Photo < ApplicationRecord
  include Transformable

  belongs_to :entry, touch: true, counter_cache: true, optional: true
  belongs_to :camera, optional: true
  belongs_to :lens, optional: true
  belongs_to :film, optional: true
  belongs_to :park, optional: true
  has_one_attached :image
  has_many :crops, dependent: :destroy
  has_many :photo_territories, dependent: :destroy
  has_many :territories, through: :photo_territories

  acts_as_list scope: :entry

  # Total white space, in pixels, guaranteed around an Instagram feed image.
  INSTAGRAM_MATTE = 100

  after_create_commit :extract_metadata, :detect_colors, :encode_blurhash

  after_commit :touch_entry
  after_commit :geocode, if: :changed_coordinates?
  after_commit :update_native_lands, if: :changed_coordinates?
  after_commit :update_entry_equipment_tags, if: :changed_equipment?
  after_commit :update_entry_location_tags, if: :changed_location?
  after_commit :update_entry_style_tags, if: :changed_style?
  after_commit :update_entry_caption_validity, if: :changed_caption_attributes?
  # The first photo is the entry's standard.site cover image, and replacing it doesn't change any
  # column the entry's own callback watches.
  after_commit :sync_entry_standard_site

  scope :needs_alt_text_review, -> { where(alt_text: [nil, ""]).or(where(alt_text_needs_review: true)) }

  def approve_auto_generated_alt_text!(text)
    update!(
      alt_text: text,
      alt_text_needs_review: false
    )
  end

  def touch_entry
    self.entry.touch unless self.entry.destroyed?
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

  def update_entry_caption_validity
    return if self.entry.nil? || self.entry.destroyed?
    CaptionValidityJob.perform_async(self.entry.id)
  end

  def self.oldest
    order('taken_at ASC').limit(1)&.first
  end

  def url(opts = {})
    opts[:crop] = calculate_crop(opts) unless opts[:contain]
    transformed_image_url(self.image.key, opts.compact)
  end

  def srcset(srcset:, src: nil, opts: {})
    widths = has_dimensions? ? srcset.reject { |width| width > self.width } : srcset
    widths = widths.uniq.sort
    src_width = src || widths.first

    opts[:crop] = calculate_crop(opts) unless opts[:contain]
    src = transformed_image_url(self.image.key, opts.merge(width: src_width).compact)
    srcset = widths.map { |w| "#{transformed_image_url(self.image.key, opts.merge(width: w).compact)} #{w}w" }.join(', ')
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

  # Returns the url of the image, matted on white to fit Instagram's frame:
  # 4:5 for vertical photos, 1:1 for everything else.
  #
  # The photo is padded onto an inner frame, inset on the axis it would
  # otherwise meet, and that result is padded onto the full frame — which
  # leaves white on all four sides. Cloudflare's URL transformations can't do
  # this, because they can't be chained: a transform URL isn't fetchable as
  # another transform's source. So it's rendered by the images worker's /ig/
  # route, which chains the Images binding instead.
  def instagram_url
    if self.is_vertical?
      outer = [1440, 1800]
      inner = [outer.first, outer.last - INSTAGRAM_MATTE]
    else
      outer = [1440, 1440]
      inner = [outer.first - INSTAGRAM_MATTE, outer.last]
    end

    "https://#{ENV['DOMAIN']}/ig/#{inner.join('x')}/#{outer.join('x')}/#{self.image.key}"
  end

  # Returns the url of the image, formatted & sized to fit into instagram stories'
  # 16:9 ratio
  def instagram_story_url(crop: false)
    opts = if crop
      { width: 2160, aspect_ratio: '9:16', quality: 100, format: 'jpeg' }
    else
      { width: 2160, height: 3840, contain: true, background: '000', quality: 100, format: 'jpeg' }
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

  def threads_url
    opts = { width: 1440, format: 'jpeg' }
    self.url(opts)
  end

  def bluesky_url
    max_dimension = 4000
    width = if self.is_vertical?
      width_from_height([self.height, max_dimension].min)
    elsif has_dimensions?
      [self.width, max_dimension].min
    else
      max_dimension
    end
    # The image service takes a size in pixels and promises nothing in bytes, so use a
    # conservative fixed quality to stay under Bluesky's ~2 MB limit.
    opts = { width: width, format: 'jpeg', quality: 80 }
    self.url(opts)
  end

  def sitemap_url
    opts = { width: 1200, format: 'jpeg' }
    self.url(opts)
  end

  def claude_url
    width = self.is_vertical? ? width_from_height(1024) : 1024
    opts = { width: width, format: 'jpeg', quality: 60 }
    self.url(opts)
  end

  def iphone_wallpaper_url
    opts = { aspect_ratio: '9:19.5' }
    self.url(opts)
  end

  def crop(aspect_ratio)
    return if aspect_ratio.blank?
    # Memoize crop lookups to avoid repeated queries for the same aspect ratio
    @crop_cache ||= {}
    return @crop_cache[aspect_ratio] if @crop_cache.key?(aspect_ratio)
    @crop_cache[aspect_ratio] = if association(:crops).loaded?
      crops.find { |c| c.aspect_ratio == aspect_ratio }
    else
      crops.find_by(aspect_ratio: aspect_ratio)
    end
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

  # Ensures the image's dimensions are recorded in its blob metadata.
  #
  # Photos are processed by asynchronous jobs that need the image's dimensions,
  # but those jobs can run before ActiveStorage has analyzed the blob. Rather
  # than passively failing and waiting for a retry to coincide with analysis,
  # we trigger analysis here so the job can proceed. Idempotent: a no-op once
  # dimensions are present.
  def ensure_analyzed!
    return if has_dimensions?
    return unless image.attached?

    image.analyze
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
    parts = location_parts
    parts.reject(&:blank?).uniq.join(', ').gsub("'", "'")
  end

  def location_parts
    if self.park.present?
      park_location_parts
    elsif self.location.present?
      custom_location_parts
    else
      default_location_parts
    end
  end

  def is_santiago_de_chile?
    self.administrative_area == 'Región Metropolitana' && self.country == 'Chile'
  end

  def is_buenos_aires?
    self.administrative_area == 'Buenos Aires' && self.country == 'Argentina'
  end

  def is_mexico_city?
    self.locality == 'Ciudad de México' && self.country == 'Mexico'
  end

  def is_new_york_city?
    (self.administrative_area == 'New York' && self.country == 'United States' ) &&
    (self.locality == 'New York' || ['Manhattan', 'Brooklyn', 'Queens', 'Bronx', 'Staten Island'].include?(self.sublocality))
  end

  def park_location_parts
    if show_region?
      [self.park.display_name, self.administrative_area, self.country]
    else
      [self.park.display_name, self.country]
    end
  end

  def instagram_location_id
    self.park&.instagram_location_id&.presence
  end

  def threads_location_id
    return "805973970760744" if self.location == "National Elk Refuge"
    self.park&.threads_location_id&.presence
  end

  def custom_location_parts
    if show_region?
      [self.location, self.administrative_area, self.country]
    else
      [self.location, self.country]
    end
  end

  def default_location_parts
    return ['Mexico City, Mexico'] if is_mexico_city?
    return ['Buenos Aires, Argentina'] if is_buenos_aires?
    return ['Santiago, Chile'] if is_santiago_de_chile?
    return [self.sublocality, "New York City", self.country] if is_new_york_city?

    if show_region?
      [self.locality, self.administrative_area, self.country]
    else
      [self.locality, self.country]
    end
  end

  def show_region?
    ['United States', 'United Kingdom', 'Canada'].include?(self.country)
  end

  def territory_list
    return unless territories.any?
    names = territories.map(&:name)

    if names.size > 2
      last = names.pop
      "#{names.join(', ')}, and #{last}"
    else
      names.join(' and ')
    end
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

  # Fetches the given image URLs to pre-warm the CDN's image cache, so they're ready
  # when external APIs (Instagram, Threads, etc.) try to download them.
  #
  # GET rather than HEAD, whose response an HTTP cache won't store — and won't use to
  # answer the GET that follows. The body is discarded here; the point is the copy it
  # leaves at the edge. Because the images Worker's cache is tiered, warming from Fly
  # populates the upper tier, so this helps wherever the download comes from rather
  # than only the data center nearest the app.
  #
  # @param urls [Array<String>] the image URLs to warm.
  def warm_cache(*urls)
    urls.each do |url|
      Rails.logger.info("[CacheWarm] Warming image cache: #{url}")
      HTTParty.get(url, timeout: 30)
    rescue => e
      Rails.logger.warn("[CacheWarm] Failed to warm cache for #{url}: #{e.message}")
    end
  end

  def extract_metadata
    PhotoExifJob.perform_async(self.id)
  end

  def generate_alt_text
    AltTextJob.perform_async(self.id)
  end

  def geocode
    PhotoGeocodeJob.perform_async(self.id)
  end

  def update_native_lands
    NativeLandsJob.perform_async(self.id)
  end

  def detect_colors
    ColorDetectionJob.perform_async(self.id)
  end

  def encode_blurhash
    BlurhashJob.perform_async(self.id)
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

  def blurhash_svg_data_uri
    return unless self.has_dimensions? && self.blurhash.present?
    Rails.cache.fetch("#{cache_key_with_version}/blurhash-svg-data-uri") do
      data_uri = blurhash_data_uri
      return unless data_uri
      svg = <<~SVG.squish
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 #{width} #{height}">
          <filter id="blur" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB">
            <feGaussianBlur stdDeviation="100" edgeMode="duplicate" />
            <feComponentTransfer>
              <feFuncA type="discrete" tableValues="1 1" />
            </feComponentTransfer>
          </filter>
          <image filter="url(#blur)" xlink:href="#{data_uri}" x="0" y="0" height="100%" width="100%"/>
        </svg>
      SVG
      "data:image/svg+xml;charset=utf-8,#{ERB::Util.url_encode(svg)}"
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

  def changed_caption_attributes?
    changed_location? || changed_equipment?
  end

  # @return [void]
  def sync_entry_standard_site
    return if self.entry.blank? || !self.entry.blog&.standard_site_enabled?

    StandardSiteJob.perform_async('sync_document', self.entry_id)
  end
end
