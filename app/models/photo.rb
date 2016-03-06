class Photo < ActiveRecord::Base
  include Formattable

  belongs_to :entry, touch: true, counter_cache: true
  has_attached_file :image,
    storage: :s3,
    s3_credentials: { access_key_id: ENV['aws_access_key_id'],
                      secret_access_key: ENV['aws_secret_access_key'],
                      bucket: ENV['s3_bucket'] },
    url: ':s3_domain_url',
    path: 'photos/:hash.:extension',
    hash_secret: ENV['secret_key_base'],
    use_timestamp: false

  acts_as_list scope: :entry

  validates_attachment_content_type :image, :content_type => /image\/jpe?g/i

  attr_accessor :source_file

  before_create :set_image
  after_image_post_process :save_exif, :save_dimensions

  def original_url
    self.image.url
  end

  def original_path
    self.image.path
  end

  def url(opts)
    opts.reverse_merge!(w: 1200, q: 90, auto: 'format', square: false)
    if opts[:square]
      opts[:h] = opts[:w]
      opts[:fit] = 'crop'
      opts.delete(:square)
    end
    Ix.path(self.original_path).to_url(opts.reject { |k,v| v.blank? })
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

  def height_from_width(width)
    ((self.height.to_f * width.to_f)/self.width.to_f).round
  end

  def width_from_height(height)
    ((self.width.to_f * height.to_f)/self.height.to_f).round
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
      self.f_number = exif.try(:f_number).try(:to_f)
      self.focal_length = exif.try(:focal_length).try(:to_i)
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
    self.film_make = film_make.try(:first).try(:gsub, /^film make:/i, '').try(:strip)
    self.film_type = film_type.try(:first).try(:gsub, /^film type:/i, '').try(:strip)
  end
end
