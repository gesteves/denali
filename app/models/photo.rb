class Photo < ActiveRecord::Base
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

  def original_url
    self.image.url
  end

  def url(width, height = 0, quality = 90, upscale = false)
    filters = ["quality(#{quality})"]
    filters << 'no_upscale()' unless upscale
    ApplicationController.helpers.thumbor_url self.original_url, width: width, height: height, smart: false, filters: filters
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
end
