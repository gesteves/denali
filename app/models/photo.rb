require 'exifr/jpeg'

class Photo < ApplicationRecord
  include Formattable

  belongs_to :entry, touch: true, counter_cache: true
  has_attached_file :image,
    storage: :s3,
    s3_credentials: { access_key_id: ENV['aws_access_key_id'],
                      secret_access_key: ENV['aws_secret_access_key'],
                      bucket: ENV['s3_bucket'] },
    s3_headers: { 'Cache-Control': 'max-age=31536000, public' },
    s3_region: ENV['s3_region'],
    s3_protocol: 'https',
    url: ':s3_path_url',
    path: 'photos/:hash.:extension',
    hash_secret: ENV['secret_key_base'],
    use_timestamp: false

  acts_as_list scope: :entry

  validates_attachment_content_type :image, :content_type => /image\/jpe?g/i

  attr_accessor :source_file

  before_create :set_image
  after_image_post_process :save_exif, :save_dimensions

  after_save :update_entry

  def update_entry
    self.entry.touch
    self.entry.update_tags
  end

  def self.oldest
    order('taken_at ASC').limit(1)&.first
  end

  def original_url
    self.paperclip_image_url
  end

  def original_path
    return '' if self.paperclip_image_url.blank?
    self.paperclip_image_url.gsub("https://s3.amazonaws.com/#{ENV['s3_bucket']}", '')
  end

  def url(opts = {})
    opts.reverse_merge!(w: 1200, auto: 'format', square: false)
    if opts[:square]
      opts[:h] = opts[:w]
      opts.delete(:square)
      opts.delete(:ch)
    end
    if opts[:w].present? && opts[:h].present? && opts[:h] != height_from_width(opts[:w]) && !opts[:fit].present?
      opts[:fit] = 'crop'
      if self.focal_x.present? && self.focal_y.present?
        opts[:crop] = 'focalpoint'
        opts['fp-x'] = self.focal_x
        opts['fp-y'] = self.focal_y
      else
        opts[:crop] = 'faces'
      end
    end
    if opts[:fm].present?
      opts.delete(:auto)
    end
    Ix.path(self.original_path).to_url(opts.reject { |k,v| v.blank? })
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
    Ix.path(self.original_path).to_url(opts)
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

  def geocode
    GeocodeJob.perform_later(self)
  end

  def annotate
    ImageAnnotationJob.perform_later(self)
  end

  def update_palette
    PaletteJob.perform_later(self)
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

  private
  def set_image
    if self.source_url.present?
      self.image = URI.parse(self.source_url)
    elsif self.source_file.present?
      self.image = self.source_file
    else
      self.image = nil
    end
  end

  def save_dimensions
    tempfile = image.queued_for_write[:original]
    unless tempfile.nil?
      geometry = Paperclip::Geometry.from_file(tempfile)
      geometry.auto_orient
      self.width = geometry.width.to_i
      self.height = geometry.height.to_i
    end
  end

  def save_exif
    exif = EXIFR::JPEG.new(image.queued_for_write[:original].path)
    unless exif.nil? || !exif.exif?
      self.make = exif.make
      self.model = exif.model
      self.iso = exif.iso_speed_ratings
      self.taken_at = exif.date_time
      self.exposure = exif.exposure_time
      self.f_number = exif&.f_number&.to_f
      self.focal_length = exif&.focal_length&.to_i
      save_gps_info(exif.gps) if exif.gps.present?
      save_film_info(exif.user_comment) if exif.user_comment.present?
    end
  end

  def save_gps_info(gps)
    self.longitude = gps.longitude
    self.latitude = gps.latitude
  end

  def save_film_info(comment)
    comment_array = comment.split(/(\n)+/).select{ |c| c =~ /^film/i }
    film_make = comment_array.select{ |c| c =~ /^film make/i }
    film_type = comment_array.select{ |c| c =~ /^film type/i }
    self.film_make = film_make&.first&.gsub(/^film make:/i, '')&.strip
    self.film_type = film_type&.first&.gsub(/^film type:/i, '')&.strip
  end
end
