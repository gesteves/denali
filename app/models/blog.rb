class Blog < ApplicationRecord
  include Formattable

  has_many :entries, dependent: :destroy
  has_attached_file :favicon,
    storage: :s3,
    s3_credentials: { access_key_id: ENV['aws_access_key_id'],
                      secret_access_key: ENV['aws_secret_access_key'],
                      bucket: ENV['s3_bucket'] },
    s3_headers: { 'Cache-Control': 'max-age=31536000, public' },
    s3_region: ENV['s3_region'],
    s3_protocol: 'http',
    url: ':s3_domain_url',
    path: 'icons/favicon-:updated_at.:extension',
    hash_secret: ENV['secret_key_base'],
    use_timestamp: true
  has_attached_file :touch_icon,
    storage: :s3,
    s3_credentials: { access_key_id: ENV['aws_access_key_id'],
                      secret_access_key: ENV['aws_secret_access_key'],
                      bucket: ENV['s3_bucket'] },
    s3_headers: { 'Cache-Control': 'max-age=31536000, public' },
    s3_region: ENV['s3_region'],
    s3_protocol: 'http',
    url: ':s3_domain_url',
    path: 'icons/touch-icon-:updated_at.:extension',
    hash_secret: ENV['secret_key_base'],
    use_timestamp: true

  validates :name, :description, :about, presence: true
  validates_attachment :favicon, content_type: { content_type: 'image/png' }
  validates_attachment :touch_icon, content_type: { content_type: 'image/png' }

  def formatted_description
    markdown_to_html(self.description)
  end

  def plain_description
    markdown_to_plaintext(self.description)
  end

  def formatted_about
    markdown_to_html(self.about)
  end

  def plain_about
    markdown_to_plaintext(self.about)
  end

  def favicon_url(opts = {})
    opts.reverse_merge!(w: 16)
    self.favicon.present? ? Ix.path(self.favicon.path).to_url(opts.reject { |k,v| v.blank? }) : nil
  end

  def touch_icon_url(opts = {})
    opts.reverse_merge!(w: 32)
    self.touch_icon.present? ? Ix.path(self.touch_icon.path).to_url(opts.reject { |k,v| v.blank? }) : nil
  end
end
