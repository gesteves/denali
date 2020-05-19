class Blog < ApplicationRecord
  include Rails.application.routes.url_helpers
  include Formattable

  has_many :entries, dependent: :destroy
  has_many :webhooks, dependent: :destroy
  has_many :publish_schedules, -> { order 'hour ASC' }, dependent: :destroy
  has_many :tag_customizations, -> { order 'updated_at DESC' }, dependent: :destroy
  has_one_attached :favicon
  has_one_attached :touch_icon
  has_one_attached :logo

  after_commit :check_for_invalidation, if: :saved_changes?

  validates :name, :tag_line, :about, presence: true

  attr_accessor :cache_ttl

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

  def twitter_handle
    self.twitter&.gsub(/^https:\/\/(www\.)?twitter.com\//, '@')
  end

  def has_search?
    Rails.env.development? || ENV['ELASTICSEARCH_URL'].present? || ENV['SEARCHBOX_URL'].present?
  end

  def past_publish_schedules_today
    current_time = Time.current.in_time_zone(self.time_zone)
    self.publish_schedules.where('hour <= ?', current_time.hour)
  end

  def pending_publish_schedules_today
    current_time = Time.current.in_time_zone(self.time_zone)
    self.publish_schedules.where('hour > ?', current_time.hour)
  end

  def publish_date_for_new_queued_post
    if self.publish_schedules_count == 0
      nil
    else
      days = (((self.entries.queued&.last&.position || 0) + self.past_publish_schedules_today.count)/(self.publish_schedules_count || 1)).floor
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

  def check_for_invalidation
    attributes = %w{
      additional_meta_tags
      analytics_body
      analytics_head
      copyright
      email
      facebook
      flickr
      header_logo_svg
      instagram
      meta_description
      name
      posts_per_page
      show_related_entries
      show_search
      tag_line
      time_zone
      tumblr
      twitter
      webfonts_url
    }

    if attributes.any? { |attr| saved_change_to_attribute? (attr) }
      self.invalidate
    elsif saved_change_to_about?
      self.invalidate(paths: about_path, clear_cache: false)
    end
  end

  def invalidate(paths: '/*', clear_cache: true)
    if clear_cache
      Rails.cache.clear
      HerokuConfigWorker.perform_async({ CACHE_VERSION: Time.now.to_i.to_s })
    end
    CloudfrontInvalidationWorker.perform_async(paths)
  end
end
