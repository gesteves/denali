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
    opts.reverse_merge!(w: 512, fm: 'jpg')
    Ix.path(self.avatar.key).to_url(opts.compact)
  end

  def banner_url(opts = {})
    return if photo.blank?
    opts.reverse_merge!(w: 1500, ar: '3:1', fm: 'jpg')
    photo.url(opts)
  end

  # Workaround for Mastodon's inability to read escaped characters in the `ar` query param
  def mastodon_banner_url(opts = {})
    return if photo.blank?
    opts.reverse_merge!(w: 1500, h: 500, fm: 'jpg')
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
