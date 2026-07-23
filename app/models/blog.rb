class Blog < ApplicationRecord
  include Rails.application.routes.url_helpers
  include Formattable
  include Thumborizable

  has_many :entries, dependent: :destroy
  has_many :webhooks, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy
  has_many :publish_schedules, -> { order 'hour ASC' }, dependent: :destroy
  has_many :tag_customizations, -> { order 'updated_at DESC' }, dependent: :destroy
  has_one_attached :favicon
  has_one_attached :touch_icon
  has_one_attached :logo
  has_one_attached :og_image
  has_one_attached :placeholder

  validates :name, :about, presence: true

  def formatted_about
    markdown_to_html(self.about)
  end

  def plain_about
    markdown_to_plaintext(self.about)
  end

  def favicon_url(opts = {})
    opts.reverse_merge!(width: 16, format: 'png')
    thumbor_url(self.favicon.key, opts)
  end

  def touch_icon_url(opts = {})
    opts.reverse_merge!(width: 32, format: 'png')
    thumbor_url(self.touch_icon.key, opts)
  end

  def logo_url(opts = {})
    opts.reverse_merge!(height: 60, format: 'png')
    thumbor_url(self.logo.key, opts)
  end

  def og_image_url(opts = {})
    opts.reverse_merge!(width: 1200, height: 630, format: 'jpeg')
    thumbor_url(self.og_image.key, opts)
  end

  def placeholder_url(opts = {})
    thumbor_url(self.placeholder.key, opts)
  end

  def placeholder_srcset(srcset:, opts: {})
    opts.reverse_merge!(format: 'jpeg')
    widths = srcset.reject { |width| width > self.placeholder.metadata[:width] }
    src_width = widths.first
    src = thumbor_url(self.placeholder.key, opts.merge(width: src_width).compact)
    srcset = widths.map { |w| "#{thumbor_url(self.placeholder.key, opts.merge(width: w).compact)} #{w}w" }.join(', ')
    return src, srcset
  end

  def placeholder_processed?
    placeholder&.attached? && placeholder&.analyzed? && placeholder&.identified?
  end

  def placeholder_aspect_ratio
    return 0 if !placeholder_processed?
    (placeholder.metadata[:height].to_f/placeholder.metadata[:width].to_f).floor(2)
  end

  def placeholder_height_from_aspect_ratio(aspect_ratio)
    return nil if placeholder.metadata[:width].blank?
    ar = aspect_ratio.split(':').map(&:to_f)
    ((placeholder.metadata[:width].to_f * ar.last)/ar.first).round
  end

  def has_search?
    Rails.env.development? || ENV['ELASTICSEARCH_URL'].present?
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

  # The Cache-Tag values whose cached responses this blog's settings appear in.
  # The name, tag line and posts-per-page render into list pages as well as the
  # site chrome, so both tags go.
  #
  # Purged from Admin::BlogsController rather than an after_commit callback:
  # entries belong_to :blog, touch: true, so a callback would have to tell a
  # settings change from a touch, and dirty tracking can't — a touched record
  # keeps the saved_changes of whatever its in-memory instance last really
  # saved. Settings only ever change in the admin, so purge there, where the
  # intent is unambiguous.
  def cache_tags
    [CacheTags::BLOG, CacheTags::ENTRIES]
  end

  # Records that the settings themselves changed, as opposed to updated_at,
  # which entries move constantly through belongs_to :blog, touch: true.
  #
  # Conditional GETs need a validator that changes when the chrome does: an
  # entry page's Last-Modified is its entry's, so purging the edge leaves every
  # browser holding a copy that still revalidates to a 304. Keying that
  # validator on updated_at instead would go too far the other way and expire
  # every page whenever a background photo job touches an entry. Bumped from
  # Admin::BlogsController for the same reason the purge lives there — that's
  # the only place a settings change is unambiguous.
  def settings_changed!
    touch(:settings_updated_at)
  end
end
