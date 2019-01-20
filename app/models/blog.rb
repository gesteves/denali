class Blog < ApplicationRecord
  include Formattable

  has_many :entries, dependent: :destroy
  has_many :publish_schedules, -> { order 'hour ASC' }, dependent: :destroy
  has_one_attached :favicon
  has_one_attached :touch_icon
  has_one_attached :logo

  validates :name, :description, :about, presence: true

  def formatted_description
    markdown_to_html(self.description)
  end

  def plain_description
    markdown_to_plaintext(self.description)
  end

  def formatted_about
    markdown_to_html(self.about)
  end

  def plain_about
    markdown_to_plaintext(self.about)
  end

  def favicon_url(opts = {})
    opts.reverse_merge!(w: 16)
    Ix.path(self.favicon.key).to_url(opts.reject { |k,v| v.blank? })
  end

  def touch_icon_url(opts = {})
    opts.reverse_merge!(w: 32)
    Ix.path(self.touch_icon.key).to_url(opts.reject { |k,v| v.blank? })
  end

  def logo_url(opts = {})
    opts.reverse_merge!(h: 60)
    Ix.path(self.logo.key).to_url(opts.reject { |k,v| v.blank? })
  end

  def has_search?
    Rails.env.development? || ENV['ELASTICSEARCH_URL'].present?
  end

  def queued_entries_published_per_day
    self.publish_schedules_count || 0
  end

  def publish_date_for_new_queued_post
    days = if self.queued_entries_published_per_day == 0
      0
    else
      ((self.entries.queued.last.position + self.entries.published_today.count)/self.queued_entries_published_per_day).floor
    end
    Time.current + days.days
  end

  def publish_queued_entry!
    self.entries.queued&.first&.publish if self.time_to_publish_queued_entry?
  end

  def time_to_publish_queued_entry?
    current_time = Time.current
    self.publish_schedules.where(hour: current_time.hour).count > 0
  end
end
