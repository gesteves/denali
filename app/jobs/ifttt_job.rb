class IftttJob < EntryJob

  queue_as :default

  def perform(entry)
    url = "https://maker.ifttt.com/trigger/#{ENV['ifttt_event']}/with/key/#{ENV['ifttt_key']}"
    body = {
      value1: entry.title,
      value2: permalink_url(entry)
    }
    body[:value3] = entry.photos.first.url(2048) if entry.is_photo?
    HTTParty.post(url, body: body.to_json)
  end
end
