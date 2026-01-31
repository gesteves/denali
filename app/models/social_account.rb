class SocialAccount < ApplicationRecord
  belongs_to :user

  encrypts :access_token

  PROVIDERS = %w[bluesky mastodon].freeze

  before_validation :normalize_handle

  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :provider, uniqueness: { scope: :user_id, message: "account already connected" }
  validates :handle, presence: true
  validates :access_token, presence: true
  validates :server_url, presence: true

  scope :bluesky, -> { where(provider: 'bluesky') }
  scope :mastodon, -> { where(provider: 'mastodon') }

  def bluesky?
    provider == 'bluesky'
  end

  def mastodon?
    provider == 'mastodon'
  end

  private

  def normalize_handle
    self.handle = handle.sub(/\A@/, '') if handle.present?
  end
end
