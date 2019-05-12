class BufferWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  private

  def get_profile_ids(service)
    return if ENV['buffer_access_token'].blank?
    response = HTTParty.get("https://api.bufferapp.com/1/profiles.json?access_token=#{ENV['buffer_access_token']}")
    begin
      profiles = JSON.parse(response.body)
      profiles.select { |profile| profile['service'].downcase.match(service) }.map { |profile| profile['id'] }
    rescue
      []
    end
  end

  def post_to_buffer(service, opts = {})
    profile_ids = get_profile_ids(service)
    return if profile_ids.blank?
    opts.reverse_merge!(profile_ids: profile_ids, shorten: false, now: Rails.env.production?, access_token: ENV['buffer_access_token'])
    response = HTTParty.post('https://api.bufferapp.com/1/updates/create.json', body: opts)
    if response.code >= 400
      logger.error "[#{service.capitalize}] #{response.body}"
      raise "Failed to post to Buffer: #{response.body}"
    end
  end

  def media_hash(photo, opts = {})
    opts.reverse_merge!(w: 2048)
    media = {
      photo: photo.url(w: opts[:w], fm: 'jpg'),
      thumbnail: photo.url(w: 512, fm: 'jpg')
    }
    media[:alt_text] = photo.alt_text if photo.alt_text.present?
    media
  end
end
