class BufferJob < EntryJob
  include ActionView::Helpers::TextHelper
  queue_as :default

  def perform(entry, service)
    HTTParty.post('https://api.bufferapp.com/1/updates/create.json', body: build_body(entry, service))
  end

  def build_body(entry, service)
    body = {
      profile_ids: get_profile_ids(service),
      text: build_text(entry, service),
      shorten: false,
      now: true,
      access_token: ENV['buffer_access_token']
    }
    body[:media] = build_media(entry) if entry.is_photo?
    body
  end

  def build_text(entry, service)
    if service == 'twitter'
      caption = entry.tweet_text.blank? ? entry.formatted_title : entry.formatted_tweet_text
      caption = truncate(caption, length: 90, omission: '…')
    else
      caption = entry.formatted_title
    end
    "#{caption} #{permalink_url(entry)}"
  end

  def build_media(entry)
    {
      picture: entry.photos.first.url(2560),
      thumbnail: entry.photos.first.url(512, 512)
    }
  end

  def get_profile_ids(service)
    response = JSON.parse(HTTParty.get("https://api.bufferapp.com/1/profiles.json?access_token=#{ENV['buffer_access_token']}").body)
    response.select{ |profile| profile['service'].downcase.match(service) }.map{ |profile| profile['id'] }
  end
end
