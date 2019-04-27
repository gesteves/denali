class AmpValidationWorker < ApplicationWorker
  sidekiq_options queue: 'low'

  def perform(entry_id)
    return if !Rails.env.production?
    begin
      entry = Entry.find(entry_id)
      path = entry.amp_url.gsub(/https?:\/\//, '')
      url = "https://amp.cloudflare.com/q/#{path}"
      response = HTTParty.get(url)
      raise 'Failed to validate AMP' if response.code >= 400
      validation = JSON.parse(response.body)
      entry.valid_amp = validation['valid']
      entry.save!
    rescue
    end
  end
end
