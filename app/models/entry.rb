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
  before_save :update_caption_validity, if: :changed_caption_fields?

  after_commit :handle_status_change, if: :saved_change_to_status?

  acts_as_taggable_on :tags, :equipment, :locations, :styles
  acts_as_list scope: :blog

  accepts_nested_attributes_for :photos, allow_destroy: true, reject_if: lambda { |attributes| attributes['image'].blank? && attributes['id'].blank? }

  settings index: { number_of_shards: 1 } do
    settings do
      mappings dynamic: false do
        indexes :id, type: :integer
        indexes :blog_id, type: :integer
        indexes :status, type: :keyword
        indexes :photos_count, type: :integer
        indexes :published_at, type: :date
        indexes :created_at, type: :date

        indexes :plain_title, type: :text, analyzer: :search_analyzer
        indexes :plain_body, type: :text, analyzer: :search_analyzer
        indexes :es_alt_text, type: :text, analyzer: :search_analyzer
        indexes :es_tags, type: :text, analyzer: :search_analyzer
        indexes :es_tag_slugs, type: :text, analyzer: :standard
        indexes :es_territories, type: :text, analyzer: :search_analyzer
        indexes :es_parks, type: :text, analyzer: :search_analyzer

        # Keyword fields for exact matching and aggregations
        indexes :tag_names, type: :keyword
        indexes :tag_slugs, type: :keyword
      end
    end

    settings analysis: {
      filter: {
        asciifolding_preserve: {
          type: :asciifolding,
          preserve_original: true
        }
      },
      analyzer: {
        search_analyzer: {
          type: :custom,
          tokenizer: :standard,
          filter: [:lowercase, :asciifolding_preserve]
        }
      }
    }
  end

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
                           :es_alt_text,
                           :es_parks,
                           :tag_names,
                           :tag_slugs])
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

  def self.indexable_in_search_engines
    where(status: 'published', hide_from_search_engines: false).order('published_at ASC')
  end

  # Scopes for shareable entries on social platforms
  def self.shareable_on_bluesky(not_shared_in: 1.year)
    where(post_to_bluesky: true)
      .where("last_shared_on_bluesky_at IS NULL OR last_shared_on_bluesky_at < ?", not_shared_in.ago)
  end

  def self.shareable_on_mastodon(not_shared_in: 1.year)
    where(post_to_mastodon: true)
      .where("last_shared_on_mastodon_at IS NULL OR last_shared_on_mastodon_at < ?", not_shared_in.ago)
  end

  def self.shareable_on_threads(not_shared_in: 1.year)
    where(post_to_threads: true)
      .where("last_shared_on_threads_at IS NULL OR last_shared_on_threads_at < ?", not_shared_in.ago)
  end

  def self.shareable_on_instagram(not_shared_in: 1.year)
    where(post_to_instagram: true)
      .where("last_shared_on_instagram_at IS NULL OR last_shared_on_instagram_at < ?", not_shared_in.ago)
  end

  def self.with_minimum_bluesky_shares
    where(bluesky_shares_count: minimum(:bluesky_shares_count))
  end

  def self.with_minimum_mastodon_shares
    where(mastodon_shares_count: minimum(:mastodon_shares_count))
  end

  def self.with_minimum_threads_shares
    where(threads_shares_count: minimum(:threads_shares_count))
  end

  def self.with_minimum_instagram_shares
    where(instagram_shares_count: minimum(:instagram_shares_count))
  end

  def self.by_bluesky_share_priority
    reorder(:bluesky_shares_count, Arel.sql("COALESCE(last_shared_on_bluesky_at, published_at) ASC"))
  end

  def self.by_mastodon_share_priority
    reorder(:mastodon_shares_count, Arel.sql("COALESCE(last_shared_on_mastodon_at, published_at) ASC"))
  end

  def self.by_threads_share_priority
    reorder(:threads_shares_count, Arel.sql("COALESCE(last_shared_on_threads_at, published_at) ASC"))
  end

  def self.by_instagram_share_priority
    reorder(:instagram_shares_count, Arel.sql("COALESCE(last_shared_on_instagram_at, published_at) ASC"))
  end

  def self.full_search(query, page = 1, per_page = 10)
    search = {
      query: {
        multi_match: {
          query: query,
          fields: ['plain_title', 'plain_body', 'es_tags^3', 'es_alt_text', 'es_territories', 'es_parks^2'],
          type: 'best_fields',
          operator: 'and',
          fuzziness: 'AUTO',
          prefix_length: 2
        }
      },
      sort: [
        '_score',
        { created_at: 'desc' }
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
            {
              multi_match: {
                query: query,
                fields: ['plain_title', 'plain_body', 'es_tags^3', 'es_alt_text', 'es_territories', 'es_parks^2'],
                type: 'best_fields',
                operator: 'and',
                fuzziness: 'AUTO',
                prefix_length: 2
              }
            }
          ]
        }
      },
      aggs: {
        matching_tags: {
          terms: { field: 'tag_names', size: 10 }
        }
      },
      sort: [
        '_score',
        { published_at: 'desc' }
      ],
      size: per_page,
      from: (page.to_i - 1) * per_page
    }
    self.search(search)
  end

  # Search with tag suggestions - returns both entries and top tags from results
  def self.search_with_tag_suggestions(query, page = 1, per_page = 10)
    # Run ES search with aggregations
    es_results = published_search(query, page, per_page)

    # Get the most common tags from the search results via ES aggregations
    suggested_tags = []
    if es_results.response.aggregations&.matching_tags&.buckets
      # ES returns buckets ordered by doc_count (most common first)
      es_tag_names = es_results.response.aggregations.matching_tags.buckets.map { |b| b['key'] }

      # Get tag IDs from 'tags' or 'locations' contexts
      valid_tag_ids = ActsAsTaggableOn::Tagging
        .where(context: ['tags', 'locations'])
        .distinct
        .pluck(:tag_id)

      # Get tag IDs from 'equipment' or 'styles' contexts to exclude
      excluded_tag_ids = ActsAsTaggableOn::Tagging
        .where(context: ['equipment', 'styles'])
        .distinct
        .pluck(:tag_id)

      # Subtract excluded from valid
      filtered_tag_ids = valid_tag_ids - excluded_tag_ids

      tags_by_name = ActsAsTaggableOn::Tag
        .where(name: es_tag_names, id: filtered_tag_ids)
        .index_by(&:name)

      # Preserve ES frequency order, filter to valid tags, take top 5
      suggested_tags = es_tag_names.map { |name| tags_by_name[name] }.compact.take(5)
    end

    { entries: es_results, suggested_tags: suggested_tags }
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

  def territories(photos_collection = nil)
    return unless self.show_location?
    return @territories if defined?(@territories) && photos_collection.nil?
    photos_to_check = photos_collection || (association(:photos).loaded? ? self.photos : self.photos.where.not(territories: nil))
    result = photos_to_check.select { |p| p.territories.present? }.map { |p| JSON.parse(p.territories) }.flatten.uniq
    @territories = result if photos_collection.nil?
    result
  end

  def territory_list(photos_collection = nil)
    return unless self.show_location?
    return @territory_list if defined?(@territory_list) && photos_collection.nil?
    territory_data = self.territories(photos_collection)
    return unless territory_data.present?
    result = if territory_data.size > 2
      temporary_list = territory_data.dup
      last = temporary_list.pop
      "#{temporary_list.join(', ')}, and #{last}"
    else
      territory_data.join(' and ')
    end
    @territory_list = result if photos_collection.nil?
    result
  end

  def meta_description(photo = nil)
    photo ||= self.photos.first
    photo&.alt_text.presence || self.plain_body
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
      entry_long_url(self.id, self.slug, params.compact)
    else
      preview_entry_url(self.preview_hash, self.slug, params.compact)
    end
  end

  def short_permalink_url(opts = {})
    host = ENV['DOMAIN_SHORT'] || Rails.application.routes.default_url_options[:host]
    entry_url(self.id.to_s(36), url_opts(host: host))
  end

  def enqueue_publish_jobs
    OpenGraphWorker.perform_async(self.id)
    MastodonWorker.perform_async(self.id, self.mastodon_caption(utm_campaign: 'new-photo')) if self.post_to_mastodon
    BlueskyWorker.perform_async(self.id, self.bluesky_caption(utm_campaign: 'new-photo')) if self.post_to_bluesky
    InstagramWorker.perform_async(self.id, self.instagram_caption) if self.post_to_instagram
    ThreadsWorker.perform_async(self.id, self.threads_caption(utm_campaign: 'new-photo')) if self.post_to_threads
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
    taggings = association(:taggings).loaded? ? self.taggings : self.taggings.includes(:tag)
    taggings.map(&:tag).uniq.compact
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

  def tag_names
    combined_tags.map(&:name)
  end

  def tag_slugs
    combined_tags.map(&:slug)
  end

  def es_alt_text
    self.photos.map { |p| p.alt_text }.reject(&:blank?).join(' ')
  end

  def es_territories
    return '' unless self.show_location?
    self.photos.where.not(territories: nil).map { |p| JSON.parse(p.territories) }.flatten.uniq.join(' ')
  end

  def es_parks
    parks = self.photos.includes(:park).map(&:park).compact.uniq
    return '' if parks.empty?

    # Collect park codes (e.g., "yose") and generated initials (e.g., "ynp" from "Yosemite National Park")
    codes_and_initials = parks.flat_map do |park|
      result = []
      result << park.code.downcase if park.code.present?
      # Generate initials from display_name (e.g., "Yosemite National Park" -> "ynp")
      if park.display_name.present?
        initials = park.display_name.split.map { |word| word[0] }.join.downcase
        result << initials if initials.length > 1
      end
      result
    end

    codes_and_initials.uniq.join(' ')
  end

  def bluesky_hashtags(count = 5)
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

    self.blog.tag_customizations.where.not(bluesky_hashtags: [nil, '']).each do |tag_customization|
      hashtags = tag_customization.bluesky_hashtags_to_a
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

    bluesky_tags = ['#Photography'] + more_tags.shuffle + tags.shuffle + location_tags.shuffle + equipment_tags.shuffle + style_tags.shuffle
    bluesky_tags.flatten.compact.uniq.take(count).shuffle.join(' ')
  end

  def mastodon_hashtags(count = 5)
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

    self.blog.tag_customizations.where.not(mastodon_hashtags: [nil, '']).each do |tag_customization|
      hashtags = tag_customization.mastodon_hashtags_to_a
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

    mastodon_tags = ['#Photography'] + more_tags.shuffle + tags.shuffle + location_tags.shuffle + equipment_tags.shuffle + style_tags.shuffle
    mastodon_tags.flatten.compact.uniq.take(count).shuffle.join(' ')
  end

  def mastodon_caption(utm_source: 'Mastodon', utm_medium: 'social', utm_campaign: nil)
    meta = []

    if is_single_photo?
      photo = photos.first
      meta << "📷 #{photo.formatted_camera}" if photo.formatted_camera.present?
      meta << "🎞 #{photo.formatted_exif}" if photo.formatted_exif.present? && photo.film.blank?
      meta << "🎞 #{photo.film.display_name}" if photo.film.present?
    end

    meta << "🔗 #{self.permalink_url(utm_source: utm_source, utm_medium: utm_medium, utm_campaign: utm_campaign)}"
    meta << "\n#{mastodon_hashtags}" if mastodon_hashtags.present?

    caption = [self.plain_title]
    caption << self.mastodon_text if self.mastodon_text.present?
    caption << meta.join("\n").strip
    caption.reject(&:blank?).join("\n\n")
  end

  def bluesky_caption(utm_source: 'Bluesky', utm_medium: 'social', utm_campaign: nil)
    meta = []

    if is_single_photo?
      photo = photos.first
      meta << "📷 #{photo.formatted_camera}" if photo.formatted_camera.present?
      meta << "🎞 #{photo.formatted_exif}" if photo.formatted_exif.present? && photo.film.blank?
      meta << "🎞 #{photo.film.display_name}" if photo.film.present?
    end

    meta << "🏷️ #{bluesky_hashtags}" if bluesky_hashtags.present?

    caption = []
    caption << "[#{self.plain_title}](#{self.permalink_url(utm_source: utm_source, utm_medium: utm_medium, utm_campaign: utm_campaign)})"
    caption << self.bluesky_text if self.bluesky_text.present?
    caption << meta.join("\n").strip
    caption.reject(&:blank?).join("\n\n")
  end

  def instagram_caption
    meta = []

    if is_single_photo?
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
    caption << self.instagram_text if self.instagram_text.present?
    caption << meta.join("\n").strip
    caption.reject(&:blank?).join("\n\n")
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
    instagram_tags.flatten.compact.uniq.take(count).shuffle.join(' ')
  end

  def threads_caption(utm_source: 'Threads', utm_medium: 'social', utm_campaign: nil)
    meta = []

    if is_single_photo?
      photo = photos.first
      meta << "📷 #{photo.formatted_camera}" if photo.formatted_camera.present?
      meta << "🎞 #{photo.formatted_exif}" if photo.formatted_exif.present? && photo.film.blank?
      meta << "🎞 #{photo.film.display_name}" if photo.film.present?

      location = []
      location << photo.formatted_location if photo.formatted_location.present?
      location << "#{photo.territory_list} land" if photo.territories.present?

      meta << "📍 #{location.join(' – ')}" if location.present? && self.show_location?
    end

    meta << "🔗 #{self.permalink_url(utm_source: utm_source, utm_medium: utm_medium, utm_campaign: utm_campaign)}"

    caption = [self.plain_title]
    caption << self.threads_text if self.threads_text.present?
    caption << meta.join("\n").strip
    caption.reject(&:blank?).join("\n\n")
  end

  def threads_topic
    entry_tags = self.tags
    entry_locations = self.locations
    entry_equipment = self.equipment
    entry_styles = self.styles
    combined_tags = self.combined_tags
    topics = []
    location_topics = []
    equipment_topics = []
    style_topics = []
    more_topics = []

    self.blog.tag_customizations.where.not(threads_topics: [nil, '']).each do |tag_customization|
      topics_array = tag_customization.threads_topics_to_a
      if tag_customization.matches_tags? entry_tags
        topics.concat(topics_array)
      elsif tag_customization.matches_tags? entry_locations
        location_topics.concat(topics_array)
      elsif tag_customization.matches_tags? entry_equipment
        equipment_topics.concat(topics_array)
      elsif tag_customization.matches_tags? entry_styles
        style_topics.concat(topics_array)
      elsif tag_customization.matches_tags? combined_tags
        more_topics.concat(topics_array)
      end
    end

    all_topics = ['Photographers of Threads'] + more_topics + topics + location_topics + equipment_topics + style_topics
    all_topics.uniq.sample.presence
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

  def update_caption_validity
    return if new_record?
    self.valid_bluesky_caption = Bluesky.valid_post_length?(bluesky_caption)
    self.valid_mastodon_caption = mastodon_caption.length <= 500
    self.valid_instagram_caption = instagram_caption.length <= 2200
    self.valid_threads_caption = threads_caption.length <= 500
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

  def changed_caption_fields?
    title_changed? ||
    mastodon_text_changed? ||
    bluesky_text_changed? ||
    instagram_text_changed? ||
    threads_text_changed?
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
