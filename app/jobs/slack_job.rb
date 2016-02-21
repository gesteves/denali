class SlackJob < ApplicationJob
  queue_as :default

  def perform(entry, webhook)
    payload = { text: '', channel: webhook.channel }
    attachment = {
      fallback: "#{entry.plain_title} #{permalink_url(entry)}",
      title: entry.plain_title,
      title_link: permalink_url(entry),
      image_url: entry.photos.first.url(800),
      color: '#BF0222'
    }
    attachment[:text] = entry.plain_body if entry.body.present?
    payload[:attachments] = [attachment]
    request = HTTParty.post(webhook.url, body: payload.to_json) if Rails.env.production?
    webhook.destroy if request.code == 404
  end
end
