class SlackJob < ApplicationJob
  queue_as :default

  def perform(entry, webhook)
    payload = { text: '', channel: webhook.channel }
    attachment = {
      fallback: "#{entry.plain_title} #{entry.permalink_url}",
      title: entry.plain_title,
      title_link: entry.permalink_url,
      image_url: entry.photos.first.url(w: 800),
      color: '#BF0222'
    }
    attachment[:text] = entry.plain_body if entry.body.present?
    payload[:attachments] = [attachment]
    response = HTTParty.post(webhook.url, body: payload.to_json) unless Rails.env.test?
    if response.code == 404
      webhook.destroy
    elsif response.code >= 400
      raise response.body
    end
  end
end
