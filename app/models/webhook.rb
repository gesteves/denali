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
    { text: "New entry published: #{entry.permalink_url}", unfurl_links: true }.to_json
  end

  def cleanup_url
    self.url = self.url.strip
  end
end
