require 'elasticsearch/model'
class Entry < ApplicationRecord
  include Elasticsearch::Model
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TextHelper
  include Formattable

  has_many :photos, -> { order 'position ASC' }, dependent: :destroy
  belongs_to :blog, touch: true
  belongs_to :user

  validates :title, presence: true

  before_save :set_published_date, if: :is_published?
  before_save :set_entry_slug
  before_save :set_preview_hash
  before_save :set_sensitive

  after_commit :handle_status_change, if: :saved_change_to_status?

  acts_as_taggable_on :tags, :equipment, :locations, :styles
  acts_as_list scope: :blog

  accepts_nested_attributes_for :photos, allow_destroy: true, reject_if: lambda { |attributes| attributes['image'].blank? && attributes['id'].blank? }

  settings index: { number_of_shards: 1 }

  after_commit on: [:create] do
    ElasticsearchWorker.perform_async(self.id, 'create')
  end

  after_commit on: [:update] do
    ElasticsearchWorker.perform_async(self.id, 'update')
  end

  after_commit on: [:destroy] do
    ElasticsearchWorker.perform_async(self.id, 'destroy')
  end

  def as_indexed_json(opts = nil)
    self.as_json(only: [:photos_count,
                        :status,
                        :published_at,
                        :created_at,
                        :blog_id,
                        :id],
                 methods: [:plain_body,
                           :plain_title,
                           :es_territories,
                           :es_tags,
                           :es_tag_slugs,
                           :es_alt_text])
  end

  def self.published(order = 'entries.published_at DESC')
    where(status: 'published').order(order)
  end

  def self.drafted(order = 'entries.updated_at DESC')
    where(status: 'draft').order(order)
  end

  def self.queued(order = 'entries.position ASC')
    where(status: 'queued').order(order)
  end

  def self.mapped
    joins(:photos).where(entries: { show_location: true }).where.not(photos: { latitude: nil }).where.not(photos: { longitude: nil })
  end

  def self.by_user(user)
    where(user_id: user.id)
  end

  def self.text_entries
    where('photos_count = 0')
  end

  def self.photo_entries
    where('photos_count > 0')
  end

  def self.posted_on_tumblr(order = 'entries.published_at DESC')
    where(status: 'published').where.not(tumblr_id: nil).order(order)
  end

  def self.indexable_in_search_engines
    where(status: 'published', hide_from_search_engines: false).order('published_at ASC')
  end

  def self.full_search(query, page = 1, per_page = 10)
    search = {
      query: {
        bool: {
          must: [
            { query_string: { query: query, default_operator: 'AND' } }
          ]
        }
      },
      sort: [
        { created_at: 'desc' },
        '_score'
      ],
      size: per_page,
      from: (page.to_i - 1) * per_page
    }
    self.search(search)
  end

  def self.published_search(query, page = 1, per_page = 10)
    search = {
      query: {
        bool: {
          must: [
            { term: { status: 'published' } },
            { range: { photos_count: { gt: 0 } } },
            { multi_match: { query: query, fields: ['plain_*', 'es_*'], type: 'cross_fields', operator: 'and' } }
          ]
        }
      },
      sort: [
        { published_at: 'desc' },
        '_score'
      ],
      size: per_page,
      from: (page.to_i - 1) * per_page
    }
    self.search(search)
  end

  def self.published_today
    where('published_at >= ? and published_at <= ?', Time.current.beginning_of_day, Time.current.end_of_day)
  end

  def self.find_by_url(url:)
    valid_controllers = ['entries']
    valid_actions = ['show', 'amp']
    url = Rails.application.routes.recognize_path(url)
    raise ActiveRecord::RecordNotFound unless valid_controllers.include?(url[:controller]) && valid_actions.include?(url[:action])

    if url[:id].present?
      Entry.published.find(url[:id])
    elsif url[:preview_hash].present?
      Entry.find_by!(preview_hash: url[:preview_hash])
    else
      raise ActiveRecord::RecordNotFound
    end
  rescue StandardError
    raise ActiveRecord::RecordNotFound
  end

  def is_photo?
    !self.photos_count.blank? && self.photos_count > 0
  end

  def is_photoset?
    !self.photos_count.blank? && self.photos_count > 1
  end

  def is_text?
    self.photos_count.blank? || self.photos_count == 0
  end

  def is_single_photo?
    !self.photos_count.blank? && self.photos_count == 1
  end

  def is_queued?
    self.status == 'queued'
  end

  def is_draft?
    self.status == 'draft'
  end

  def is_published?
    self.status == 'published'
  end

  def publish
    self.status = 'published'
    self.save
  end

  def queue
    unless status == 'published'
      self.status = 'queued'
      self.save
    end
  end

  def draft
    unless status == 'published'
      self.status = 'draft'
      self.save
    end
  end

  def add_to_list
    insert_at(Entry.queued.size)
  end

  def newer
    if self.is_published?
      Entry.published('published_at ASC').where('published_at > ?', self.published_at).where.not(id: self.id).limit(1)&.first
    else
      nil
    end
  end

  def older
    if self.is_published?
      Entry.published.where('published_at < ?', self.published_at).where.not(id: self.id).limit(1)&.first
    else
      Entry.published.first
    end
  end

  def publish_date_for_queued
    if self.blog.publish_schedules_count == 0
      nil
    else
      days = ((self.position - 1 + self.blog.past_publish_schedules_today.count)/(self.blog.publish_schedules_count || 1)).floor
      Time.current + days.days
    end
  end

  def related(count: 12)
    begin
      Entry.search(related_query(count)).records.includes(photos: [:image_attachment, :image_blob, :crops])
    rescue => e
      logger.error "Fetching related entries failed with the following error: #{e}"
      nil
    end
  end

  def formatted_body
    markdown_to_html(self.body)
  end

  def plain_body
    markdown_to_plaintext(self.body)
  end

  def plain_title
    markdown_to_plaintext(self.title)
  end

  def territories
    return unless self.show_location?
    self.photos.where.not(territories: nil).map { |p| JSON.parse(p.territories) }.flatten.uniq
  end

  def territory_list
    return unless self.show_location? && self.territories.present?
    territory_list = if self.territories.size > 2
      temporary_list = self.territories
      last = temporary_list.pop
      "#{temporary_list.join(', ')}, and #{last}"
    else
      self.territories.join(' and ')
    end
    territory_list
  end

  def meta_description
    self&.photos&.first&.alt_text.presence || self.plain_body
  end

  def permalink_path
    if self.is_published?
      entry_long_path(self.id, self.slug)
    else
      preview_entry_path(self.preview_hash, self.slug)
    end
  end

  def permalink_url(params = {})
    if self.is_published?
      entry_long_url(self.id, self.slug, params)
    else
      preview_entry_url(self.preview_hash, self.slug, params)
    end
  end

  def short_permalink_url(opts = {})
    host = ENV['DOMAIN_SHORT'] || Rails.application.routes.default_url_options[:host]
    entry_url(self.id.to_s(36), url_opts(host: host))
  end

  def enqueue_publish_jobs
    OpenGraphWorker.perform_async(self.id)
    InstagramWorker.perform_async(self.id, self.instagram_caption) if self.post_to_instagram
    MastodonWorker.perform_async(self.id, self.mastodon_caption) if self.post_to_mastodon
    BlueskyWorker.perform_async(self.id, self.bluesky_caption) if self.post_to_bluesky
    TumblrWorker.perform_async(self.id) if self.post_to_tumblr
    Webhook.deliver_all(self)
    PushSubscription.deliver_all(self)
    self.send_photos_to_flickr if self.post_to_flickr
    self.purge_from_cdn
  end

  def purge_from_cdn
    self.touch
    self.older&.touch
    self.newer&.touch

    paths = if self.is_published?
      ["#{entry_long_path(self.id)}/*", self.newer&.permalink_path, self.older&.permalink_path]
    else
      [self.permalink_path]
    end

    wildcard_paths = %w{
      /
      /page*
      /sitemap*
      /feed*
      /oembed*
      /search*
      /related*
      /activitypub*
      /nodeinfo*
    }

    if self.is_published?
      paths.concat(wildcard_paths)
      paths.concat(self.combined_tags.map { |tag| "/tagged/#{tag.slug}*"})
    end

    paths = paths.flatten.reject(&:blank?).uniq
    CloudfrontInvalidationWorker.perform_async(paths)
  end

  def send_photos_to_flickr
    self.photos.each { |p| FlickrWorker.perform_async(p.id) }
  end

  def combined_tags
    self.taggings.includes(:tag).map(&:tag).uniq.compact
  end

  def combined_tag_list
    self.combined_tags.map(&:name)
  end

  def es_tags
    self.combined_tags.map(&:name).join(' ')
  end

  def es_tag_slugs
    self.combined_tags.map { |t| t.slug.gsub(/-/, '') }.join(' ')
  end

  def es_alt_text
    self.photos.map { |p| p.alt_text }.reject(&:blank?).join(' ')
  end

  def es_territories
    return '' unless self.show_location?
    self.photos.where.not(territories: nil).map { |p| JSON.parse(p.territories) }.flatten.uniq.join(' ')
  end

  def instagram_hashtags(count = 30)
    entry_tags = self.tags
    entry_locations = self.locations
    entry_equipment = self.equipment
    entry_styles = self.styles
    combined_tags = self.combined_tags
    tags = []
    location_tags = []
    equipment_tags = []
    style_tags = []
    more_tags = []

    self.blog.tag_customizations.where.not(instagram_hashtags: [nil, '']).each do |tag_customization|
      hashtags = tag_customization.instagram_hashtags_to_a
      if tag_customization.matches_tags? entry_tags
        tags << hashtags
      elsif tag_customization.matches_tags? entry_locations
        location_tags << hashtags
      elsif tag_customization.matches_tags? entry_equipment
        equipment_tags << hashtags
      elsif tag_customization.matches_tags? entry_styles
        style_tags << hashtags
      elsif tag_customization.matches_tags? combined_tags
        more_tags << hashtags
      end
    end

    instagram_tags = more_tags.shuffle + tags.shuffle + location_tags.shuffle + equipment_tags.shuffle + style_tags.shuffle
    instagram_tags.flatten.compact.uniq[0, count].shuffle.join(' ')
  end

  def instagram_caption
    meta = []

    if is_photo?
      photo = photos.first
      meta << "📷 #{photo.formatted_camera}" if photo.formatted_camera.present?
      meta << "🎞 #{photo.formatted_exif}" if photo.formatted_exif.present? && photo.film.blank?
      meta << "🎞 #{photo.film.display_name}" if photo.film.present?

      location = []
      location << photo.formatted_location if photo.formatted_location.present?
      location << "#{photo.territory_list} land" if photo.territories.present?

      meta << "📍 #{location.join(' – ')}" if location.present? && self.show_location?
    end

    caption = [self.plain_title]
    if self.instagram_text.present?
      caption << self.instagram_text
    else
      caption << self.plain_body
    end

    caption << meta.join("\n").strip
    caption.reject(&:blank?).join("\n\n")
  end

  def mastodon_tags
    valid_tags = %w{ Landscapes Wildlife }
    mastodon_tags = []
    mastodon_tags << 'Photography' if is_photo?
    mastodon_tags += combined_tag_list & valid_tags
    mastodon_tags.map { |t| "##{t}" }.join(' ')
  end

  def mastodon_caption
    meta = []

    meta << "🔗 #{self.permalink_url}"
    meta << "🏷️ #{mastodon_tags}" if mastodon_tags.present?

    caption = []
    if self.mastodon_text.present?
      caption << self.mastodon_text
    else
      caption << self.plain_title
    end

    caption << meta.join("\n").strip
    caption.reject(&:blank?).join("\n\n")
  end

  def bluesky_caption
    meta = []

    meta << "🔗 #{self.permalink_url}"
    meta << "🏷️ #{bluesky_tags}" if bluesky_tags.present?

    caption = []
    if self.bluesky_text.present?
      caption << self.bluesky_text
    else
      caption << self.plain_title
    end

    caption << meta.join("\n").strip
    caption.reject(&:blank?).join("\n\n")
  end

  def bluesky_tags
    mammals = ['Bears', 'Wolves', 'Coyotes', 'Bison', 'Moose', 'Red Foxes', 'Pronghorn', 'Porcupines', 'Bighorn Sheep']
    mastodon_tags = []
    mastodon_tags << 'mammals' if (combined_tag_list & mammals).present?
    mastodon_tags.map { |t| "##{t}" }.join(' ')
  end


  def plain_caption
    text = []
    text << self.plain_title
    text << self.plain_body
    text << self.permalink_url
    text.reject(&:blank?).join("\n\n")
  end

  def flickr_groups(count = 60)
    entry_tags = self.combined_tags
    entry_groups = []
    return entry_groups unless self.post_to_flickr_groups
    self.blog.tag_customizations.where.not(flickr_groups: [nil, '']).each do |tag_customization|
      flickr_groups = tag_customization.flickr_groups_to_a
      if tag_customization.matches_tags? entry_tags
        entry_groups << flickr_groups
      end
    end
    entry_groups.flatten.compact.uniq[0, count]
  end

  def flickr_albums
    entry_tags = self.combined_tags
    entry_albums = []
    self.blog.tag_customizations.where.not(flickr_albums: [nil, '']).each do |tag_customization|
      flickr_albums = tag_customization.flickr_albums_to_a
      if tag_customization.matches_tags? entry_tags
        entry_albums << flickr_albums
      end
    end
    entry_albums.flatten.compact.uniq
  end

  def tumblr_caption(html: false)
    meta = []

    if is_photo?
      photo = photos.first
      meta << "📷 #{photo.formatted_camera}" if photo.formatted_camera.present?
      meta << "🎞 #{photo.formatted_exif}" if photo.formatted_exif.present? && photo.film.blank?
      meta << "🎞 #{photo.film.display_name}" if photo.film.present?

      location = []
      location << photo.formatted_location if photo.formatted_location.present?
      location << "#{photo.territory_list} land" if photo.territories.present?

      meta << "📍 #{location.join(' – ')}" if location.present? && self.show_location?
    end

    caption = []
    caption << "[#{self.plain_title}](#{self.permalink_url})"

    if self.tumblr_text.present?
      caption << self.tumblr_text
    else
      caption << self.body
    end

    caption << meta.join("  \n").strip
    markdown = caption.reject(&:blank?).join("\n\n")

    html ? markdown_to_html(markdown) : markdown
  end

  def tumblr_tags
    entry_tags = self.tags
    entry_locations = self.locations
    entry_equipment = self.equipment
    entry_styles = self.styles
    combined_tags = self.combined_tags
    basic_tags = self.tag_list.clone
    location_tags = self.location_list.clone
    equipment_tags = self.equipment_list.clone
    style_tags = self.style_list.clone
    more_tags = self.combined_tag_list.clone
    more_tags += ["Photographers on Tumblr", "Original Photographers"] if self.is_photo?

    self.blog.tag_customizations.where.not(tumblr_tags: [nil, '']).each do |tag_customization|
      hashtags = tag_customization.tumblr_tags_to_a
      if tag_customization.matches_tags? entry_tags
        basic_tags << hashtags
      elsif tag_customization.matches_tags? entry_locations
        location_tags << hashtags
      elsif tag_customization.matches_tags? entry_equipment
        equipment_tags << hashtags
      elsif tag_customization.matches_tags? entry_styles
        style_tags << hashtags
      elsif tag_customization.matches_tags? combined_tags
        more_tags << hashtags
      end
    end

    tumblr_tags = basic_tags + location_tags + more_tags + equipment_tags + style_tags
    tumblr_tags += ['mature'] if self.is_sensitive?
    tumblr_tags.flatten.compact.uniq.map(&:downcase).sort.join(', ')
  end

  def update_tags
    self.update_equipment_tags
    self.update_location_tags
    self.update_style_tags
  end

  def update_equipment_tags
    equipment_tags = []
    self.photos.each do |p|
      equipment_tags << [p.camera&.make, p.camera&.display_name, p.film&.display_name]
      equipment_tags << p.lens&.display_name unless p.camera&.is_phone?
    end
    equipment_tags = equipment_tags.flatten.uniq.reject(&:blank?)
    self.equipment_list = equipment_tags
    self.tag_list.remove(equipment_tags)
    self.save!
  end

  def update_location_tags
    location_tags = []
    tags = []
    self.tag_list.remove(Park.designations.map(&:pluralize) + Park.names + self.location_list)
    if self.show_location?
      self.photos.each do |p|
        if p.park.present?
          location_tags += [p.park.display_name, p.country, p.administrative_area].uniq.reject(&:blank?)
          tags << p.park.designation.pluralize if p.park.designation.present?
        else
          location_tags += [p.location, p.country, p.locality, p.sublocality, p.neighborhood, p.administrative_area].uniq.reject(&:blank?)
        end
      end
    end
    location_tags = location_tags.uniq.reject(&:blank?)
    self.location_list = location_tags
    self.tag_list.add(tags.uniq)
    self.save!
  end

  def update_style_tags
    style_tags = []
    self.photos.each do |p|
      style_tags << (p.color? ? 'Color' : 'Black and White') unless p.color?.nil?
      style_tags << 'Film' if p.film.present?
      style_tags << 'Mobile' if p.camera&.is_phone?
    end
    style_tags = style_tags.flatten.uniq.reject(&:blank?)
    self.style_list = style_tags
    self.tag_list.remove(['Color', 'Black and White', 'Film', 'Mobile'])
    self.save!
  end

  def add_tags(new_tags)
    self.tag_list.add(new_tags, parse: true)
    self.tag_list.remove(self.equipment_list + self.location_list + ['Color', 'Black and White', 'Film', 'Mobile'])
    self.save!
  end

  def handle_status_change
    case status
    when 'published'
      remove_from_list
      enqueue_publish_jobs
    when 'draft'
      remove_from_list
    when 'queued'
      add_to_list
    end
  end

  def photos_have_dimensions?
    photos.all? { |p| p.has_dimensions? }
  end

  def is_published_on_tumblr?
    tumblr_id.present? && tumblr_reblog_key.present?
  end

  def is_on_tumblr?
    tumblr_id.present?
  end

  def tumblr_reblog_url
    return unless is_published_on_tumblr?
    "https://www.tumblr.com/reblog/#{user.profile.tumblr_username}/#{tumblr_id}/#{tumblr_reblog_key}"
  end

  def tumblr_url
    return unless is_published_on_tumblr?
    "https://www.tumblr.com/#{user.profile.tumblr_username}/#{tumblr_id}/"
  end

  def track_recently_shared(platform)
    key = "recently_shared:#{platform.downcase}"
    default_limit = 100

    limit = ENV['SHARE_RANDOM_PHOTOS_LIMIT']&.to_i
    limit = default_limit unless limit&.positive?
    limit -= 1

    $redis.lpush(key, self.id)
    $redis.ltrim(key, 0, limit)
  end

  private

  def url_opts(opts)
    if Rails.env.production?
      opts.reverse_merge!(protocol: Rails.configuration.force_ssl ? 'https' : 'http')
    else
      opts.reverse_merge!(only_path: true)
    end
    opts
  end

  def set_published_date
    if self.is_published? && self.published_at.blank?
      time = Time.current
      self.published_at = time
      self.modified_at  = time
    end
  end

  def set_entry_slug
    if self.slug.blank?
      self.slug = self.title.parameterize
    else
      self.slug = self.slug.parameterize
    end
  end

  def set_sensitive
    if self.content_warning.present?
      self.is_sensitive = true
    end
  end

  def set_preview_hash
    if self.preview_hash.blank?
      md5 = Digest::MD5.new
      self.preview_hash = md5.hexdigest(Time.current.to_i.to_s)
    end
  end

  def related_query(count = 12)
    entry_date = if self.is_published?
      self.published_at
    elsif self.is_queued?
      self.publish_date_for_queued
    else
      self.created_at
    end

    start_date = entry_date.beginning_of_day - 1.year
    end_date = entry_date.end_of_day + 1.year

    {
      query: {
        bool: {
          must: [
            { term: { blog_id: self.blog_id } },
            { term: { status: 'published' } },
            { range: { photos_count: { gt: 0 } } },
            { range: { published_at: { gte: start_date, lte: end_date } } }
          ],
          must_not: {
            term: { id: self.id }
          },
          should: [
            { match: { es_tag_slugs: self.es_tag_slugs } }
          ]
        }
      },
      sort: [
        '_score',
        { published_at: 'desc' }
      ],
      size: count
    }
  end
end
