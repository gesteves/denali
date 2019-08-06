class Webhook < ApplicationRecord
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
    attachment = {
      fallback: "#{entry.plain_title} #{entry.short_permalink_url}",
      title: entry.plain_title,
      title_link: entry.permalink_url,
      text: entry.plain_body,
      author_name: "#{entry.user.first_name} #{entry.user.last_name}",
      author_icon: entry.user.avatar_url,
      ts: entry.published_at.to_i
    }
    attachment[:image_url] = entry.photos.first.url(w: 1200) if entry.is_photo?
    attachment[:color] = '#BF0222'
    { text: '', attachments: [attachment] }.to_json
  end

  def cleanup_url
    self.url = self.url.strip
  end
end
