class BufferJob < ApplicationJob
  private

  def get_profile_ids(service)
    return if ENV['buffer_access_token'].blank? || !Rails.env.production?
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
    opts.reverse_merge!(profile_ids: profile_ids, shorten: false, access_token: ENV['buffer_access_token'])
    if ENV['buffer_delay_in_minutes'].present?
      minutes = ENV['buffer_delay_in_minutes'].to_i
      if minutes == 0
        opts[:now] = true
      else
        opts[:scheduled_at] = (Time.current.beginning_of_hour + minutes.minutes).to_i
      end
    end
    response = HTTParty.post('https://api.bufferapp.com/1/updates/create.json', body: opts)
    if response.code >= 400
      logger.tagged('Social', 'Buffer') { logger.error response.body }
    end
  end

  def media_hash(photo, opts = {})
    opts.reverse_merge!(w: 1200, alt_text: false)
    media = {
      photo: photo.url(w: opts[:w], fm: 'jpg'),
      thumbnail: photo.url(w: 512, fm: 'jpg')
    }
    media[:alt_text] = photo.alt_text if opts[:alt_text] && photo.alt_text.present?
    media
  end
end
