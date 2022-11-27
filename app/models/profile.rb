class Profile < ApplicationRecord
  belongs_to :user
  belongs_to :photo, optional: true
  has_one_attached :avatar

  validates :username, presence: true, uniqueness: true

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

  def banner_url
    return if photo.blank?
    photo.banner_url
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
end
