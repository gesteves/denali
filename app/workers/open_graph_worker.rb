class OpenGraphWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  def perform(entry_id)
    return if !Rails.env.production?
    return if ENV['facebook_app_id'].blank? || ENV['facebook_app_secret'].blank?
    entry = Entry.published.find(entry_id)

    params = {
      id: entry.permalink_url,
      scrape: true,
      access_token: "#{ENV['facebook_app_id']}|#{ENV['facebook_app_secret']}"
    }

    response = HTTParty.post('https://graph.facebook.com', query: params)
    response = JSON.parse(response.body)

    if response['error'].present?
      code = response['error']['code']
      message = response['error']['message']
      raise "#{code} #{message}"
    end
  end
end
