class IftttJob < EntryJob

  queue_as :default

  def perform(entry)
    url = ENV['ifttt_webhook_url']
    body = {
      value1: entry.title,
      value2: permalink_url(entry)
    }
    body[:value3] = entry.photos.first.url(2048) if entry.is_photo?
    HTTParty.post(url, body: body.to_json)
  end
end
