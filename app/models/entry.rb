require 'elasticsearch/model'
class Entry < ApplicationRecord
  include Elasticsearch::Model
  include Rails.application.routes.url_helpers
  include Formattable

  has_many :photos, -> { order 'position ASC' }, dependent: :destroy
  belongs_to :blog, touch: true
  belongs_to :user

  validates :title, presence: true

  before_save :set_published_date, if: :is_published?
  before_save :set_entry_slug
  before_create :set_preview_hash

  acts_as_taggable_on :tags, :equipment, :locations
  acts_as_list scope: :blog

  accepts_nested_attributes_for :photos, allow_destroy: true, reject_if: lambda { |attributes| attributes['source_file'].blank? && attributes['source_url'].blank? && attributes['id'].blank? }

  attr_accessor :invalidate_cloudfront

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
    self.as_json(methods: [:plain_body, :plain_title, :es_tags, :es_photo_captions])
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
    joins(:photos).includes(:photos).where(entries: { show_in_map: true, status: 'published' }).where.not(photos: { latitude: nil, longitude: nil })
  end

  def self.text_entries
    where('photos_count = 0')
  end

  def self.photo_entries
    where('photos_count > 0')
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
    self.save && self.enqueue_jobs
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
    Entry.published('published_at ASC').where('published_at > ?', self.published_at).where.not(id: self.id).limit(1).first
  end

  def older
    Entry.published.where('published_at < ?', self.published_at).where.not(id: self.id).limit(1).first
  end

  def related(count = 12)
    search = {
      query: {
        bool: {
          must: [
            { term: { blog_id: self.blog_id } },
            { term: { status: 'published' } }
          ],
          must_not: {
            match: { id: self.id }
          },
          should: {
            match: { es_tags: { query: self.es_tags } }
          },
          minimum_should_match: 1
        }
      },
      size: count
    }
    Entry.search(search).records.includes(:photos)
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
    year, month, day, id, slug = self.slug_params
    entry_long_path(year, month, day, id, slug)
  end

  def permalink_url(opts = {})
    opts.reverse_merge!(host: self.blog.domain)
    year, month, day, id, slug = self.slug_params
    entry_long_url(year, month, day, id, slug, url_opts(opts))
  end

  def short_permalink_url(opts = {})
    opts.reverse_merge!(host: self.blog.short_domain)
    entry_url(self.id, url_opts(opts))
  end

  def enqueue_jobs
    unless Rails.env.development?
      self.enqueue_twitter
      self.enqueue_tumblr
      self.enqueue_facebook
      self.enqueue_flickr
      self.enqueue_instagram
      self.enqueue_pinterest
      self.enqueue_slack
    end
    true
  end

  def enqueue_twitter
    TwitterJob.perform_later(self)  if self.is_published? && self.is_photo? && self.post_to_twitter
  end

  def enqueue_tumblr
    TumblrJob.perform_later(self) if self.is_published? && self.is_photo? && self.post_to_tumblr
  end

  def enqueue_facebook
    FacebookJob.perform_later(self) if self.is_published? && self.is_photo? && self.post_to_facebook
  end

  def enqueue_instagram
    InstagramJob.perform_later(self) if self.is_published? && self.is_photo? && self.post_to_instagram
  end

  def enqueue_flickr
    FlickrJob.perform_later(self) if self.is_published? && self.is_photo? && self.post_to_flickr
  end

  def enqueue_slack
    if self.is_published? && self.is_photo?
      attachment = {
        fallback: "#{self.plain_title} #{self.permalink_url}",
        title: self.plain_title,
        title_link: self.permalink_url,
        image_url: self.photos.first.url(w: 800),
        color: '#BF0222'
      }
      attachment[:text] = self.plain_body if self.body.present?
      SlackJob.perform_later('', attachment)
    end
  end

  def enqueue_pinterest
    PinterestJob.perform_later(self) if self.is_published? && self.is_photo? && self.post_to_pinterest
  end

  def combined_tags
    tags = self.tags + self.equipment + self.locations
    tags.uniq { |t| t.slug }
  end

  def combined_tag_list
    self.combined_tags.map(&:name)
  end

  def es_tags
    self.combined_tag_list.join(' ')
  end

  def es_photo_captions
    self.photos.map { |p| p.plain_caption }.join("\n\n")
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
      self.published_at = Time.now
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
