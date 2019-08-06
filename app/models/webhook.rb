class Webhook < ApplicationRecord
  include ActionView::Helpers::TextHelper

  belongs_to :blog

  validates :url, presence: true

  before_save :cleanup_url

  def self.deliver_all(entry)
    Webhook.where(blog: entry.blog).each do |webhook|
      WebhookWorker.perform_async(webhook.id, entry.id)
    end
  end

  def payload(entry)
    return to_ifttt(entry) if ifttt?
    return to_slack(entry) if slack?
    nil
  end

  private

  def ifttt?
    url.match?(/ifttt\.com/)
  end

  def slack?
    url.match?(/slack\.com/)
  end

  def to_ifttt(entry)
    obj = {
      value1: entry.plain_title,
      value2: entry.permalink_url
    }
    obj[:value3] = entry.photos.first.url(w: 1200) if entry.is_photo?
    obj.to_json
  end

  def to_slack(entry)
    blocks = []
    blocks << { type: 'section', text: { type: 'mrkdwn', text: "<#{entry.permalink_url}|*#{entry.plain_title}*>" } }
    blocks << { type: 'section', text: { type: 'mrkdwn', text: truncate(entry.plain_body, length: 200) } } if entry.body.present?
    blocks << { type: 'image', image_url: entry.photos.first.url(w: 1200), alt_text: entry.photos.first.alt_text } if entry.is_photo?

    { text: "#{entry.plain_title} #{entry.short_permalink_url}", blocks: blocks }.to_json
  end

  def cleanup_url
    self.url = self.url.strip
  end
end
