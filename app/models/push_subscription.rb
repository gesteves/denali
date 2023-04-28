class PushSubscription < ApplicationRecord
  require 'uri'

  belongs_to :blog

  validates :endpoint, presence: true, uniqueness: true
  validate :valid_endpoint_url
  validates :p256dh, presence: true
  validates :auth, presence: true

  def self.deliver_all(entry)
    PushSubscription.where(blog: entry.blog).find_each do |push_subscription|
      PushNotificationWorker.perform_async(push_subscription.id, entry.id)
    end
  end

  private

  def valid_endpoint_url
    uri = URI.parse(endpoint)
    errors.add(:endpoint, 'is not a valid URL') unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    errors.add(:endpoint, 'is not a valid URL')
  end
end
