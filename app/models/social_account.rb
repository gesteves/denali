class SocialAccount < ApplicationRecord
  belongs_to :user

  encrypts :access_token
  encrypts :access_token_secret

  PROVIDERS = %w[bluesky flickr instagram mastodon threads].freeze

  before_validation :normalize_handle

  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :provider, uniqueness: { scope: :user_id, message: "account already connected" }
  validates :handle, presence: true
  validates :access_token, presence: true
  validates :server_url, presence: true, unless: -> { flickr? || instagram? || threads? }

  scope :bluesky, -> { where(provider: 'bluesky') }
  scope :flickr, -> { where(provider: 'flickr') }
  scope :instagram, -> { where(provider: 'instagram') }
  scope :mastodon, -> { where(provider: 'mastodon') }
  scope :threads, -> { where(provider: 'threads') }

  def bluesky?
    provider == 'bluesky'
  end

  def flickr?
    provider == 'flickr'
  end

  def instagram?
    provider == 'instagram'
  end

  def mastodon?
    provider == 'mastodon'
  end

  def threads?
    provider == 'threads'
  end

  private

  def normalize_handle
    self.handle = handle.sub(/\A@/, '') if handle.present?
  end
end
