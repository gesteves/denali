class Profile < ApplicationRecord
  include Formattable
  include Thumborizable

  belongs_to :user
  belongs_to :photo, optional: true
  has_one_attached :avatar

  validates :username, presence: true, uniqueness: true

  before_save :parameterize_username

  def formatted_bio
    markdown_to_html(self.bio)
  end

  def plain_bio
    markdown_to_plaintext(self.bio)
  end

  def formatted_summary
    markdown_to_html(self.summary)
  end

  def plain_summary
    markdown_to_plaintext(self.summary)
  end

  def avatar_url(opts = {})
    opts.reverse_merge!(width: 512, format: 'jpeg')
    thumbor_url(self.avatar.key, opts)
  end

  def banner_url(opts = {})
    return if photo.blank?
    opts.reverse_merge!(width: 1500, aspect_ratio: '3:1', format: 'jpeg')
    photo.url(opts)
  end

  def tumblr_username
    return if self.tumblr.blank?
    uri = URI.parse(self.tumblr)
    domain = PublicSuffix.parse(uri.host)
    username = if domain.domain == 'tumblr.com' && (domain.trd.blank? || domain.trd == 'www')
      uri.path.split('/').last
    elsif domain.domain == 'tumblr.com' && domain.trd.present?
      domain.trd
    else
      domain.subdomain || domain.domain
    end
    username.presence
  end

  private

  def parameterize_username
    self.username = self.username.parameterize
  end
end
