class Webhook < ApplicationRecord
  include ActionView::Helpers::TextHelper

  belongs_to :blog

  validates :url, presence: true

  normalizes :url, with: ->(url) { url.strip }

  def self.deliver_all(entry)
    Webhook.where(blog: entry.blog).each do |webhook|
      WebhookJob.perform_async(webhook.id, entry.id)
    end
  end

  def payload(entry)
    return to_ifttt(entry) if ifttt?
    return to_slack(entry) if slack?
    return to_discord(entry) if discord?
    nil
  end

  private

  def ifttt?
    url.match?(/ifttt\.com/)
  end

  def slack?
    url.match?(/slack\.com/) || url.match?(/slack$/)
  end

  def discord?
    url.match?(/discord\.com/)
  end

  def to_ifttt(entry)
    obj = {
      value1: entry.plain_title,
      value2: entry.permalink_url
    }
    obj[:value3] = entry.photos.first.url(width: 1200) if entry.is_photo?
    obj.to_json
  end

  def to_slack(entry)
    { text: "#{title(entry)}: #{entry.permalink_url}", unfurl_links: true }.to_json
  end

  def to_discord(entry)
    { content: "#{title(entry)}: #{entry.permalink_url}" }.to_json
  end

  private

  def title(entry)
    if entry.is_photoset?
      "New photos published"
    elsif entry.is_single_photo?
      "New photo published"
    else
      "New entry published"
    end
  end
end
