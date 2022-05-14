class OpenGraphWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  def perform(entry_id)
    return if !Rails.env.production?
    return if ENV['FACEBOOK_APP_ID'].blank? || ENV['FACEBOOK_APP_SECRET'].blank?
    entry = Entry.published.find(entry_id)
    raise UnprocessedPhotoError if entry.is_photo? && !entry.photos_processed?

    params = {
      id: entry.permalink_url,
      scrape: true,
      access_token: "#{ENV['FACEBOOK_APP_ID']}|#{ENV['FACEBOOK_APP_SECRET']}"
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
