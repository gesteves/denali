class SlackJob < ApplicationJob
  queue_as :default

  def perform(entry, webhook)
    payload = { text: '', channel: webhook.channel }
    attachment = {
      fallback: "#{entry.plain_title} #{entry.permalink_url}",
      title: entry.plain_title,
      title_link: entry.permalink_url,
      image_url: entry.photos.first.url(width: 800),
      color: entry.photos.first.try(:dominant_color) || '#bf0222'
    }
    attachment[:text] = entry.plain_body if entry.body.present?
    payload[:attachments] = [attachment]
    request = HTTParty.post(webhook.url, body: payload.to_json) unless Rails.env.test?
    webhook.destroy if request.code == 404
  end
end
