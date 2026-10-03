class PushSubscription < ApplicationRecord
  require 'uri'

  # The push services browsers actually hand out endpoints for. Every publish
  # makes the server POST to each endpoint, so accepting any URL would let
  # anyone point it at internal hosts.
  PUSH_SERVICE_HOSTS = [
    /\Afcm\.googleapis\.com\z/,            # Chrome, Edge (Chromium), Opera, Samsung Internet
    /\A([a-z0-9-]+\.)?push\.services\.mozilla\.com\z/, # Firefox
    /\Aweb\.push\.apple\.com\z/,          # Safari
    /\A[a-z0-9-]+\.notify\.windows\.com\z/  # Legacy Edge
  ].freeze

  belongs_to :blog

  validates :endpoint, presence: true, uniqueness: true
  validate :valid_endpoint_url
  validates :p256dh, presence: true
  validates :auth, presence: true

  def self.deliver_all(entry)
    PushSubscription.where(blog: entry.blog).find_each do |push_subscription|
      PushNotificationJob.perform_async(push_subscription.id, entry.id)
    end
  end

  private

  def valid_endpoint_url
    return if endpoint.blank?

    uri = URI.parse(endpoint)
    if !uri.is_a?(URI::HTTPS)
      errors.add(:endpoint, 'is not a valid URL')
    elsif PUSH_SERVICE_HOSTS.none? { |host| host.match?(uri.host.to_s.downcase) }
      errors.add(:endpoint, 'is not a known push service')
    end
  rescue URI::InvalidURIError
    errors.add(:endpoint, 'is not a valid URL')
  end
end
