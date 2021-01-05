class HerokuRestartWorker < ApplicationWorker
  sidekiq_options queue: 'low'

  def perform
    return if !Rails.env.production? || ENV['HEROKU_API_TOKEN'].blank? || ENV['HEROKU_APP_NAME'].blank?

    response = HTTParty.delete("https://api.heroku.com/apps/#{ENV['HEROKU_APP_NAME']}/dynos",
                              headers: { 'Authorization': "Bearer #{ENV['HEROKU_API_TOKEN']}", 'Accept': 'application/vnd.heroku+json; version=3', 'Content-Type': 'application/json' })

    raise "Failed to restart dynos: #{response.body}" if response.code >= 400
  end
end
