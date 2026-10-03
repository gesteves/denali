class User < ApplicationRecord
  # The Google OAuth token from sign-in was stored in plain text and never read.
  # Unused columns, dropped in a later migration. Ignored first so no process
  # still running this code writes to them after they're gone.
  self.ignored_columns += %w[oauth_token oauth_expires_at]

  has_many :entries
  has_many :social_accounts, dependent: :destroy

  def bluesky_account
    social_accounts.find_by(provider: 'bluesky')
  end

  def flickr_account
    social_accounts.find_by(provider: 'flickr')
  end

  def instagram_account
    social_accounts.find_by(provider: 'instagram')
  end

  def mastodon_account
    social_accounts.find_by(provider: 'mastodon')
  end

  def threads_account
    social_accounts.find_by(provider: 'threads')
  end
end
