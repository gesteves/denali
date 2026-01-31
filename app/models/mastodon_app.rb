class MastodonApp < ApplicationRecord
  encrypts :client_secret

  validates :instance_url, presence: true, uniqueness: true
  validates :client_id, presence: true
  validates :client_secret, presence: true

  before_validation :normalize_instance_url

  class << self
    def for_instance(url)
      normalized_url = normalize_url(url)
      find_by(instance_url: normalized_url) || register_app(normalized_url)
    end

    def register_app(instance_url)
      endpoint = "#{instance_url}/api/v1/apps"
      host = ENV['DOMAIN'] || 'localhost:3000'
      protocol = Rails.env.production? ? 'https' : 'http'

      response = HTTParty.post(endpoint, body: {
        client_name: 'All-Encompassing Trip',
        redirect_uris: redirect_uri,
        scopes: 'read write:media write:statuses',
        website: Rails.application.routes.url_helpers.root_url(host: host, protocol: protocol)
      })

      if response.code == 200
        data = JSON.parse(response.body)
        create!(
          instance_url: instance_url,
          client_id: data['client_id'],
          client_secret: data['client_secret']
        )
      else
        Rails.logger.error("[MastodonApp] Failed to register app: status=#{response.code}")
        Rails.logger.error("[MastodonApp] Response body: #{response.body.truncate(500)}")
        raise "Failed to register app with Mastodon instance: #{response.code}"
      end
    end

    def redirect_uri
      host = ENV['DOMAIN'] || 'localhost:3000'
      protocol = Rails.env.production? ? 'https' : 'http'
      Rails.application.routes.url_helpers.mastodon_callback_admin_accounts_url(host: host, protocol: protocol)
    end

    def normalize_url(url)
      url = url.to_s.strip.downcase
      url = "https://#{url}" unless url.start_with?('http://', 'https://')
      url = url.sub(/^http:/, 'https:')
      url = url.chomp('/')
      url
    end
  end

  private

  def normalize_instance_url
    self.instance_url = self.class.normalize_url(instance_url) if instance_url.present?
  end
end
