class BufferJob < ApplicationJob
  queue_as :default

  def perform(entry, opts)
    opts.reverse_merge!({ include_link: true, width: 2048, include_hashtags: false, include_body: false })

    text_array = []

    if opts[:service] == 'twitter'
      max_length = 90 # 140 characters - 25 for the image url - 25 for the permalink url
      text_array << truncate(entry.plain_title, length: max_length, omission: '…')
    else
      text_array << entry.plain_title
      text_array << entry.plain_body if entry.body.present? && opts[:include_body]
    end

    text_array << entry.permalink_url if opts[:include_link]

    if opts[:include_hashtags]
      all_tags = entry.combined_tags.sort_by { |t| t.name }.map { |t| "##{t.slug.gsub(/-/, '')}" }
      all_tags += ENV['instagram_tags'].split(/,\s*/).map { |t| "##{t}" } if ENV['instagram_tags'].present? && opts[:service] == 'instagram'
      text_array << all_tags.join(' ')
    end

    text = opts[:service] == 'twitter' ? text_array.join(' ') : text_array.join("\n\n")

    media = {
      thumbnail: entry.photos.first.url(w: 512)
    }

    media[:picture] = if opts[:service] == 'instagram'
      if entry.photos.first.is_vertical?
        entry.photos.first.url(w: 1080, h: 1350, fit: 'fill', bg: 'fff')
      elsif entry.photos.first.is_horizontal?
        entry.photos.first.url(w: 1080, h: 864, fit: 'fill', bg: 'fff')
      elsif entry.photos.first.is_square?
        entry.photos.first.url(w: 1080)
      end
    else
      entry.photos.first.url(w: opts[:width])
    end

    body = {
      profile_ids: get_profile_ids(opts[:service]),
      text: text,
      media: media,
      shorten: false,
      now: true,
      access_token: ENV['buffer_access_token']
    }

    HTTParty.post('https://api.bufferapp.com/1/updates/create.json', body: body)
  end

  def get_profile_ids(service)
    response = JSON.parse(HTTParty.get("https://api.bufferapp.com/1/profiles.json?access_token=#{ENV['buffer_access_token']}").body)
    response.select { |profile| profile['service'].downcase.match(service) }.map { |profile| profile['id'] }
  end
end
