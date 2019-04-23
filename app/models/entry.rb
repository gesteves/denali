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
  before_create :set_preview_hash

  acts_as_taggable_on :tags, :equipment, :locations, :styles, :instagram_locations
  acts_as_list scope: :blog

  accepts_nested_attributes_for :photos, allow_destroy: true, reject_if: lambda { |attributes| attributes['image'].blank? && attributes['id'].blank? }

  attr_accessor :flush_caches

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
                           :es_tags,
                           :es_tag_slugs,
                           :es_alt_text])
  end

  def self.published(order = 'published_at DESC')
    where(status: 'published').order(order)
  end

  def self.drafted(order = 'updated_at DESC')
    where(status: 'draft').order(order)
  end

  def self.queued(order = 'position ASC')
    where(status: 'queued').order(order)
  end

  def self.mapped
    joins(:photos).where(entries: { show_in_map: true }).where.not(photos: { latitude: nil, longitude: nil })
  end

  def self.text_entries
    where('photos_count = 0')
  end

  def self.photo_entries
    where('photos_count > 0')
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
    self.older&.touch
    self.remove_from_list
    self.status = 'published'
    self.save && self.enqueue_sharing_jobs
  end

  def queue
    unless status == 'published'
      self.insert_at(Entry.queued.size)
      self.status = 'queued'
      self.save
    end
  end

  def draft
    unless status == 'published'
      self.remove_from_list
      self.status = 'draft'
      self.save
    end
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

  def related(count = 12)
    begin
      Entry.search(related_query(count)).records.includes(photos: [:image_attachment, :image_blob])
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

  def formatted_content(opts = {})
    opts.reverse_merge!(link_title: false)

    content = if opts[:link_title] && opts[:utm].present?
      "[#{self.title}](#{self.permalink_url(opts[:utm])})"
    elsif opts[:link_title]
      "[#{self.title}](#{self.permalink_url})"
    else
      self.title
    end

    content += "\n\n#{self.body}" unless self.body.blank?
    markdown_to_html(content)
  end

  def slug_params
    entry_date = self.published_at || self.updated_at
    year = entry_date.strftime('%Y')
    month = entry_date.strftime('%-m')
    day = entry_date.strftime('%-d')
    id = self.id
    slug = self.slug
    return year, month, day, id, slug
  end

  def permalink_path
    if self.is_published?
      year, month, day, id, slug = self.slug_params
      entry_long_path(year, month, day, id, slug)
    else
      preview_entry_path(self.preview_hash)
    end
  end

  def amp_path
    return nil unless self.is_published?
    year, month, day, id, slug = self.slug_params
    entry_amp_path(year, month, day, id, slug)
  end

  def permalink_url
    if self.is_published?
      year, month, day, id, slug = self.slug_params
      entry_long_url(year, month, day, id, slug)
    else
      preview_entry_url(self.preview_hash)
    end
  end

  def amp_url
    return nil unless self.is_published?
    year, month, day, id, slug = self.slug_params
    entry_amp_url(year, month, day, id, slug)
  end

  def short_permalink_url(opts = {})
    host = ENV['domain_short'] || Rails.application.routes.default_url_options[:host]
    entry_url(self.id, url_opts(host: host))
  end

  def enqueue_sharing_jobs
    self.send_to_ifttt
    FacebookWorker.perform_async(self.id) if self.post_to_facebook
    InstagramWorker.perform_async(self.id) if self.post_to_instagram
    TwitterWorker.perform_async(self.id) if self.post_to_twitter
    self.send_photos_to_flickr if self.post_to_flickr
    true
  end

  def send_photos_to_flickr
    self.photos.each do |p|
      FlickrWorker.perform_async(p.id)
    end
  end

  def send_to_ifttt
    payload = {
      value1: self.plain_title,
      value2: self.permalink_url
    }
    payload[:value3] = self.photos.first.url(w: 1200) if self.is_photo?
    IftttWebhookWorker.perform_async('entry-published', payload)
  end

  def combined_tags
    ActsAsTaggableOn::Tag.joins(:taggings).where('taggings.taggable_type = ? and taggings.taggable_id = ? and taggings.context != ?', 'Entry', self.id, 'instagram_locations')
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

  def instagram_location
    return nil if instagram_locations.blank?
    instagram_location_tags = self.instagram_location_list
    tc = self.blog.tag_customizations.tagged_with(instagram_location_tags, match_all: true).where.not(instagram_location_id: [nil, '']).limit(1)&.first
    if tc.present?
      location_name = tc.instagram_location_name.present? ? tc.instagram_location_name : instagram_location_tags.join(', ')
      return location_name, tc.instagram_location_id
    else
      nil
    end
  end

  def instagram_caption
    text = []
    if self.instagram_text.present?
      text << self.instagram_text
    else
      text << self.plain_title
      text << self.plain_body
    end
    text.reject(&:blank?).join("\n\n")
  end

  def flickr_groups(count = 60)
    entry_tags = self.combined_tags
    entry_groups = []
    self.blog.tag_customizations.where.not(flickr_groups: [nil, '']).each do |tag_customization|
      flickr_groups = tag_customization.flickr_groups_to_a
      if tag_customization.matches_tags? entry_tags
        entry_groups << flickr_groups
      end
    end
    entry_groups.flatten.compact.uniq[0, count]
  end

  def update_tags
    EntryTagUpdateWorker.perform_async(self.id)
  end

  def add_tags(new_tags)
    self.tag_list.add(new_tags, parse: true)
    self.tag_list.remove(self.equipment_list + self.location_list + ['Color', 'Black and White'])
    self.save!
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
    if self.is_published? && self.published_at.nil?
      time = Time.current
      self.published_at = time
      self.modified_at  = time
    end
  end

  def set_entry_slug
    if self.slug.blank?
      self.slug = self.title.split('.').first.parameterize
    else
      self.slug = self.slug.parameterize
    end
  end

  def set_preview_hash
    sha256 = Digest::SHA256.new
    self.preview_hash = sha256.hexdigest(Time.current.to_i.to_s)
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
