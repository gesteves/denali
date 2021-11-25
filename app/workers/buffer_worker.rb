class BufferWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  private

  def get_profile_ids(service)
    return if ENV['buffer_access_token'].blank?
    response = HTTParty.get("https://api.bufferapp.com/1/profiles.json?access_token=#{ENV['buffer_access_token']}")
    if response.code == 200
      profiles = JSON.parse(response.body)
      profiles.select { |profile| profile['service'].downcase.match(service) }.map { |profile| profile['id'] }
    else
      raise "#{response.code} #{response.body}"
    end
  end

  def post_to_buffer(service, opts = {})
    profile_ids = get_profile_ids(service)
    return if profile_ids.blank? || ENV['buffer_access_token'].blank?
    opts.reverse_merge!(profile_ids: profile_ids, shorten: false, now: true, access_token: ENV['buffer_access_token'])
    response = HTTParty.post('https://api.bufferapp.com/1/updates/create.json', body: opts)
    response = JSON.parse(response.body)
    if response['success']
      response['updates'].map { |u| u['id'] }
    else
      code = response['code']
      message = response['message']
      raise "#{code} #{message}"
    end
  end
end
