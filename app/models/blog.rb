class Blog < ApplicationRecord
  include Formattable

  has_many :entries, dependent: :destroy
  has_many :publish_schedules, -> { order 'hour ASC' }, dependent: :destroy
  has_one_attached :favicon
  has_one_attached :touch_icon
  has_one_attached :logo

  validates :name, :tag_line, :about, presence: true

  def formatted_tag_line
    markdown_to_html(self.tag_line)
  end

  def plain_tag_line
    markdown_to_plaintext(self.tag_line)
  end

  def formatted_about
    markdown_to_html(self.about)
  end

  def plain_about
    markdown_to_plaintext(self.about)
  end

  def favicon_url(opts = {})
    opts.reverse_merge!(w: 16, image: self.favicon.key)
    ThumborUrl.generate(opts)
  end

  def touch_icon_url(opts = {})
    opts.reverse_merge!(w: 32, image: self.touch_icon.key)
    ThumborUrl.generate(opts)
  end

  def logo_url(opts = {})
    opts.reverse_merge!(h: 60, image: self.logo.key)
    ThumborUrl.generate(opts)
  end

  def has_search?
    Rails.env.development? || ENV['ELASTICSEARCH_URL'].present?
  end

  def queued_entries_published_per_day
    self.publish_schedules_count || 0
  end

  def publish_date_for_new_queued_post
    if self.queued_entries_published_per_day == 0
      nil
    else
      days = ((self.entries.queued.last.position + self.entries.published_today.count)/self.queued_entries_published_per_day).floor
      Time.current + days.days
    end
  end

  def publish_queued_entry!
    self.entries.queued&.first&.publish if self.time_to_publish_queued_entry?
  end

  def time_to_publish_queued_entry?
    current_time = Time.current.in_time_zone(self.time_zone)
    self.publish_schedules.where(hour: current_time.hour).count > 0
  end
end
