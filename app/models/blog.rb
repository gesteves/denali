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
    s3_protocol: 'https',
    url: ':s3_path_url',
    path: 'icons/favicon-:updated_at.:extension',
    hash_secret: ENV['secret_key_base'],
    use_timestamp: false
  has_attached_file :touch_icon,
    storage: :s3,
    s3_credentials: { access_key_id: ENV['aws_access_key_id'],
                      secret_access_key: ENV['aws_secret_access_key'],
                      bucket: ENV['s3_bucket'] },
    s3_headers: { 'Cache-Control': 'max-age=31536000, public' },
    s3_region: ENV['s3_region'],
    s3_protocol: 'https',
    url: ':s3_path_url',
    path: 'icons/touch-icon-:updated_at.:extension',
    hash_secret: ENV['secret_key_base'],
    use_timestamp: false
  has_attached_file :logo,
    storage: :s3,
    s3_credentials: { access_key_id: ENV['aws_access_key_id'],
                      secret_access_key: ENV['aws_secret_access_key'],
                      bucket: ENV['s3_bucket'] },
    s3_headers: { 'Cache-Control': 'max-age=31536000, public' },
    s3_region: ENV['s3_region'],
    s3_protocol: 'https',
    url: ':s3_path_url',
    path: 'icons/logo-:updated_at.:extension',
    hash_secret: ENV['secret_key_base'],
    use_timestamp: false

  validates :name, :description, :about, presence: true
  validates_attachment :favicon, content_type: { content_type: 'image/png' }
  validates_attachment :touch_icon, content_type: { content_type: 'image/png' }
  validates_attachment :logo, content_type: { content_type: 'image/png' }

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

  def favicon_path
    return nil if self.paperclip_favicon_url.blank?
    self.paperclip_favicon_url.gsub("https://s3.amazonaws.com/#{ENV['s3_bucket']}", '')
  end

  def touch_icon_path
    return nil if self.paperclip_touch_icon_url.blank?
    self.paperclip_touch_icon_url.gsub("https://s3.amazonaws.com/#{ENV['s3_bucket']}", '')
  end

  def logo_path
    return nil if self.paperclip_logo_url.blank?
    self.paperclip_logo_url.gsub("https://s3.amazonaws.com/#{ENV['s3_bucket']}", '')
  end

  def favicon_url(opts = {})
    return nil if self.paperclip_favicon_url.blank?
    opts.reverse_merge!(w: 16)
    Ix.path(self.favicon_path).to_url(opts.reject { |k,v| v.blank? })
  end

  def touch_icon_url(opts = {})
    return nil if self.paperclip_touch_icon_url.blank?
    opts.reverse_merge!(w: 32)
    Ix.path(self.touch_icon_path).to_url(opts.reject { |k,v| v.blank? })
  end

  def logo_url(opts = {})
    return nil if self.paperclip_logo_url.blank?
    opts.reverse_merge!(h: 60)
    Ix.path(self.logo_path).to_url(opts.reject { |k,v| v.blank? })
  end

  def has_search?
    Rails.env.development? || ENV['ELASTICSEARCH_URL'].present?
  end
end
