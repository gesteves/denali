class CacheVersionWorker < ApplicationWorker
  sidekiq_options queue: 'low'

  def perform
    return if !Rails.env.production? || ENV['HEROKU_API_TOKEN'].blank? || ENV['HEROKU_APP_NAME'].blank?

    response = HTTParty.patch("https://api.heroku.com/apps/#{ENV['HEROKU_APP_NAME']}/config-vars",
                              body: { 'CACHE_VERSION': Time.now.to_i }.to_json,
                              headers: { 'Authorization': "Bearer #{ENV['HEROKU_API_TOKEN']}", 'Accept': 'application/vnd.heroku+json; version=3', 'Content-Type': 'application/json' })

    raise "Failed to update cache version: #{response.body}" if response.code >= 400
  end
end
