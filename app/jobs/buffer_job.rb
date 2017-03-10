class BufferJob < ApplicationJob
  queue_as :default

  def perform(entry, service)

    case service
    when 'twitter'
      text = text_for_twitter(entry)
      media = media(entry)
    when 'facebook'
      text = text_for_facebook(entry)
      media = media(entry)
    when 'instagram'
      text = text_for_instagram(entry)
      media = media_for_instagram(entry)
    end

    body = {
      profile_ids: get_profile_ids(service),
      text: text,
      media: media,
      shorten: false,
      now: true,
      access_token: ENV['buffer_access_token']
    }

    response = HTTParty.post('https://api.bufferapp.com/1/updates/create.json', body: body)
    raise response.code.to_s if response.code != 200
  end

  private

  def get_profile_ids(service)
    response = JSON.parse(HTTParty.get("https://api.bufferapp.com/1/profiles.json?access_token=#{ENV['buffer_access_token']}").body)
    response.select { |profile| profile['service'].downcase.match(service) }.map { |profile| profile['id'] }
  end

  def text_for_twitter(entry)
    max_length = 90 # 140 characters - 25 for the image url - 25 for the permalink url
    "#{truncate(entry.plain_title, length: max_length, omission: '…')} #{entry.permalink_url}"
  end

  def text_for_facebook(entry)
    "#{entry.plain_title}\n\n#{entry.permalink_url}"
  end

  def text_for_instagram(entry)
    all_tags = entry.combined_tags.sort_by { |t| t.name }.map { |t| "##{t.slug.gsub(/-/, '')}" }
    all_tags += ENV['instagram_tags'].split(/,\s*/).map { |t| "##{t}" } if ENV['instagram_tags'].present?

    text_array = []
    text_array << entry.plain_title
    text_array << entry.plain_body if entry.body.present?
    text_array << all_tags.join(' ')

    text_array.join("\n\n")
  end

  def media(entry)
    {
      thumbnail: entry.photos.first.url(w: 512),
      picture: entry.photos.first.url(w: 2048)
    }
  end

  def media_for_instagram(entry)
    media = {
      thumbnail: entry.photos.first.url(w: 512)
    }

    media[:picture] = if entry.photos.first.is_vertical?
      entry.photos.first.url(w: 1080, h: 1350, fit: 'fill', bg: 'fff')
    elsif entry.photos.first.is_horizontal?
      entry.photos.first.url(w: 1080, h: 864, fit: 'fill', bg: 'fff')
    elsif entry.photos.first.is_square?
      entry.photos.first.url(w: 1080)
    end

    media
  end


end
