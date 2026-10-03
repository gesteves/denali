class User < ApplicationRecord
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
