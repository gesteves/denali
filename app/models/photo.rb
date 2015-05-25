class Photo < ActiveRecord::Base
  include Formattable

  belongs_to :entry, touch: true, counter_cache: true
  has_attached_file :image,
    storage: :s3,
    s3_credentials: { access_key_id: Rails.application.secrets.aws_access_key_id,
                      secret_access_key: Rails.application.secrets.aws_secret_access_key,
                      bucket: Rails.application.secrets.s3_bucket },
    url: ':s3_domain_url',
    path: 'photos/:hash.:extension',
    hash_secret: Rails.application.secrets.secret_key_base,
    use_timestamp: false

  acts_as_list scope: :entry

  validates_attachment_content_type :image, :content_type => /image\/jpe?g/i

  attr_accessor :source_file

  before_create :set_image
  after_image_post_process :save_exif, :save_dimensions

  def original_url
    self.image.url
  end

  def url(width, height = 0, quality = 90, upscale = false)
    filters = ["quality(#{quality})"]
    filters << 'no_upscale()' unless upscale
    ApplicationController.helpers.thumbor_url self.original_url, width: width, height: height, smart: false, filters: filters
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

  private
  def set_image
    if !self.source_url.nil? && !self.source_url.blank?
      self.image = URI.parse(self.source_url)
    elsif !self.source_file.nil? && !self.source_file.blank?
      self.image = self.source_file
    else
      self.image = nil
    end
  end

  def save_dimensions
    tempfile = image.queued_for_write[:original]
    unless tempfile.nil?
      geometry = Paperclip::Geometry.from_file(tempfile)
      self.width = geometry.width.to_i
      self.height = geometry.height.to_i
    end
  end

  def save_exif
    exif = EXIFR::JPEG.new(image.queued_for_write[:original].path)
    return if exif.nil? || !exif.exif?
    self.make = exif.make
    self.model = exif.model
    self.iso = exif.iso_speed_ratings
    self.f_number = exif.f_number.to_f unless exif.f_number.nil?
    self.focal_length = exif.focal_length.to_i unless exif.focal_length.nil?
    self.longitude = exif.gps.longitude unless exif.gps.nil?
    self.latitude = exif.gps.latitude unless exif.gps.nil?
    self.taken_at = exif.date_time
    self.exposure = exif.exposure_time
    unless exif.user_comment.blank?
      comment_array = exif.user_comment.split(/(\n)+/).select{ |c| c =~ /^film/i }
      self.film_make = comment_array.select{ |c| c =~ /^film make/i }.blank? ? nil : comment_array.select{ |c| c =~ /^film make/i }.first.gsub(/^film make:/i, '').strip
      self.film_type = comment_array.select{ |c| c =~ /^film type/i }.blank? ? nil : comment_array.select{ |c| c =~ /^film type/i }.first.gsub(/^film type:/i, '').strip
    end
  end
end
