class InstagramWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  def perform(entry_id, text, now = true)
    return if !Rails.env.production?
    return if ENV['BUFFER_ACCESS_TOKEN'].blank?
    entry = Entry.published.find(entry_id)
    return if !entry.is_photo?
    raise UnprocessedPhotoError unless entry.photos_have_dimensions?

    blog = entry.blog
    return if blog.instagram.blank?

    photos = entry.photos.to_a[0..4]
    opts = {
      text: text,
      media: media_hash(photos.shift),
      now: now
    }

    if photos.present?
      opts[:extra_media] = photos.map { |p| media_hash(p) }
    else
      hashtags = entry.instagram_hashtags
      if hashtags.present?
        opts[:comment_enabled] = true
        opts[:comment_text] = hashtags
      end
    end

    post_to_buffer(opts)
  end

  private

  def media_hash(photo)
    {
      photo: photo.instagram_url
    }
  end

  def get_profile_ids
    response = HTTParty.get("https://api.bufferapp.com/1/profiles.json?access_token=#{ENV['BUFFER_ACCESS_TOKEN']}")
    if response.code == 200
      profiles = JSON.parse(response.body)
      profiles.select { |profile| profile['service'].downcase.match('instagram') }.map { |profile| profile['id'] }
    else
      raise "#{response.code} #{response.body}"
    end
  end

  def post_to_buffer(opts = {})
    profile_ids = get_profile_ids
    return if profile_ids.blank?
    opts.reverse_merge!(profile_ids: profile_ids, shorten: false, now: true, access_token: ENV['BUFFER_ACCESS_TOKEN'])
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
