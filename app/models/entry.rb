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

  acts_as_taggable_on :tags, :equipment, :locations, :styles
  acts_as_list scope: :blog

  accepts_nested_attributes_for :photos, allow_destroy: true, reject_if: lambda { |attributes| attributes['image'].blank? && attributes['id'].blank? }

  attr_accessor :flush_caches

  settings index: { number_of_shards: 1 }

  after_commit on: [:create] do
    ElasticsearchJob.perform_later(self, 'create')
  end

  after_commit on: [:update] do
    ElasticsearchJob.perform_later(self, 'update')
  end

  after_commit on: [:destroy] do
    ElasticsearchJob.perform_later(self, 'destroy')
  end

  def as_indexed_json(opts = nil)
    self.as_json(only: [:photos_count, :status, :published_at, :created_at, :blog_id, :id], methods: [:plain_body, :plain_title, :es_tags, :es_locations, :es_equipment, :es_captions, :es_styles, :es_keywords])
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
    joins(:photos).where(entries: { show_in_map: true, status: 'published' }).where.not(photos: { latitude: nil, longitude: nil })
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

  def self.queue_has_published_today?
    published.first.published_at.in_time_zone(Rails.application.config.time_zone).beginning_of_day == Time.now.in_time_zone(Rails.application.config.time_zone).beginning_of_day
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
    date = self.published_at || self.publish_date_for_queued
    Entry.published('published_at ASC').where('published_at > ?', date).where.not(id: self.id).limit(1).first
  end

  def older
    date = self.published_at || self.publish_date_for_queued
    Entry.published.where('published_at < ?', date).where.not(id: self.id).limit(1).first
  end

  def publish_date_for_queued
    days = if Entry.queue_has_published_today?
      self.position
    else
      self.position - 1
    end
    Time.now.in_time_zone(Rails.application.config.time_zone) + days.days
  end

  def related(count = 12)
    entry_date = if self.is_published?
      self.published_at
    elsif self.is_queued?
      self.publish_date_for_queued
    else
      self.created_at
    end

    start_date = entry_date.beginning_of_day - 2.year
    end_date = entry_date.end_of_day + 2.year

    begin
      search = {
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
              { match: { es_locations: { query: self.es_locations, boost: 2 } } },
              { match: { es_tags: { query: self.es_tags } } },
              { match: { es_styles: { query: self.es_styles } } }
            ],
            minimum_should_match: 1
          }
        },
        size: count
      }
      Entry.search(search).records.includes(photos: [:image_attachment, :image_blob])
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
      entry_long_url(year, month, day, id, slug, url_opts(host: ENV['domain']))
    else
      preview_entry_url(self.preview_hash, url_opts(host: ENV['domain']))
    end
  end

  def amp_url
    return nil unless self.is_published?
    year, month, day, id, slug = self.slug_params
    entry_amp_url(year, month, day, id, slug, url_opts(host: ENV['domain']))
  end

  def short_permalink_url(opts = {})
    host = ENV['domain_short'] || ENV['domain']
    entry_url(self.id, url_opts(host: host))
  end

  def enqueue_sharing_jobs
    self.enqueue_slack
    AmpCacheJob.perform_later(self)
    FacebookJob.perform_later(self) if self.post_to_facebook
    FlickrJob.perform_later(self) if self.post_to_flickr
    InstagramJob.perform_later(self) if self.post_to_instagram
    PinterestJob.perform_later(self) if self.post_to_pinterest
    TumblrJob.perform_later(self) if self.post_to_tumblr
    TwitterJob.perform_later(self) if self.post_to_twitter
    true
  end

  def enqueue_slack
    attachment = {
      fallback: "#{self.plain_title} #{self.permalink_url}",
      title: self.plain_title,
      title_link: self.permalink_url
    }
    attachment[:image_url] = self.photos.first.url(w: 800) if self.is_photo?
    attachment[:color] = '#BF0222'
    SlackJob.perform_later(attachments: [attachment])
  end

  def combined_tags
    ActsAsTaggableOn::Tag.joins(:taggings).where('taggings.taggable_type = ? and taggings.taggable_id = ?', 'Entry', self.id)
  end

  def combined_tag_list
    self.combined_tags.map(&:name)
  end

  def es_tags
    self.tags.map { |t| t.slug.gsub(/-/, '') }.join(' ')
  end

  def es_locations
    self.locations.map { |t| t.slug.gsub(/-/, '') }.join(' ')
  end

  def es_equipment
    self.equipment.map { |t| t.slug.gsub(/-/, '') }.join(' ')
  end

  def es_styles
    self.styles.map { |t| t.slug.gsub(/-/, '') }.join(' ')
  end

  def es_captions
    self.photos.map { |p| p.plain_caption }.reject(&:blank?).join(' ')
  end

  def es_keywords
    self.photos.map { |p| p.keywords }.reject(&:blank?).join(', ')
  end

  def instagram_hashtags(count = 30)
    entry_tags = self.combined_tags.map { |t| t.slug.gsub(/-/, '') }
    instagram_hashtags = YAML.load_file(Rails.root.join('config/hashtags.yml'))['instagram']

    tags = instagram_hashtags['magazines'].sample(5)
    extra_tags = instagram_hashtags['magazines']

    # For each entry tag, add 5 matching Instagram tags to the array
    instagram_hashtags.each do |k, v|
      if entry_tags.include? k
        tags += instagram_hashtags[k].sample(5)
      end
    end

    # We may have room for more Instagram tags, so build a second array with
    # every Instagram tag that matches this entry's tags.
    if tags.uniq.size < count
      instagram_hashtags.each do |k, v|
        if entry_tags.include? k
          extra_tags += instagram_hashtags[k]
        end
      end
    end

    # Shuffle and add them up, remove the duplicates, and grab the first `count`.
    # That way we end up with `count` Instagram hashtags, guaranteeing there are
    # at least a few of each matching entry tag.
    instagram_tags = tags.shuffle + extra_tags.shuffle
    instagram_tags.uniq[0, count].shuffle.map { |t| "##{t}"}.join(' ')
  end

  def instagram_caption
    text = []
    if self.instagram_text.present?
      text << self.instagram_text
    else
      text << self.plain_title
      text << self.plain_body
    end
    text << self.instagram_hashtags
    text.reject(&:blank?).join("\n\n")
  end

  def update_tags
    equipment_tags = []
    location_tags = []
    style_tags = []
    self.photos.each do |p|
      equipment_tags << [p.formatted_make, p.formatted_camera, p.formatted_film]
      style_tags << (p.color? ? "Color" : "Black and White") unless p.color?.nil?
      location_tags  << [p.country, p.locality, p.sublocality, p.neighborhood, p.administrative_area] if self.show_in_map?
    end
    equipment_tags = equipment_tags.flatten.uniq.reject(&:blank?)
    location_tags = location_tags.flatten.uniq.reject(&:blank?)
    style_tags = style_tags.flatten.uniq.reject(&:blank?)
    self.equipment_list = equipment_tags
    self.location_list = location_tags
    self.style_list = style_tags
    self.tag_list.remove(equipment_tags + location_tags + ['Color', 'Black and White'])
    self.save!
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
      time = Time.now
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

  def set_preview_hash
    sha256 = Digest::SHA256.new
    self.preview_hash = sha256.hexdigest(Time.now.to_i.to_s)
  end
end
