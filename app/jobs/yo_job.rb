class YoJob < EntryJob

  queue_as :default

  def perform(entry)
    body = {
      api_token: ENV['yo_api_token'],
      link: permalink_url(entry)
    }
    HTTParty.post('https://api.justyo.co/yoall/', body: body)
  end
end
