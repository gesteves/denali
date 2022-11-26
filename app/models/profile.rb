class Profile < ApplicationRecord
  belongs_to :user
  belongs_to :entry
  has_one_attached :avatar

  after_commit :check_for_invalidation, if: :saved_changes?

  validates :name, :username, :bio, presence: true
  validates :username, uniqueness: true

  def formatted_bio
    markdown_to_html(self.bio)
  end

  def plain_bio
    markdown_to_plaintext(self.bio)
  end

  def avatar_url(opts = {})
    opts.reverse_merge!(w: 512, fm: 'jpg')
    Ix.path(self.avatar.key).to_url(opts.compact)
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

  def check_for_invalidation
    attributes = %w{
      bio
      email
      flickr
      instagram
      meta_description
      name
      username
      summary
      tumblr
    }

    if attributes.any? { |attr| saved_change_to_attribute? (attr) }
      self.purge_from_cdn
    end
  end

  def purge_from_cdn(paths: '/*')
    Rails.cache.clear
    CloudfrontInvalidationWorker.perform_async(paths)
  end
end
