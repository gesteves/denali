class Entry < ApplicationRecord
  include Rails.application.routes.url_helpers
  include Formattable

  has_many :photos, -> { order 'position ASC' }, dependent: :destroy
  belongs_to :blog, touch: true
  belongs_to :user

  validates :title, presence: true

  before_save :set_published_date, if: :is_published?
  before_save :set_entry_slug

  acts_as_taggable_on :tags, :equipment, :locations
  acts_as_list scope: :blog

  accepts_nested_attributes_for :photos, allow_destroy: true, reject_if: lambda { |attributes| attributes['source_file'].blank? && attributes['source_url'].blank? && attributes['id'].blank? }

  attr_accessor :invalidate_cloudfront

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
    earliest_date = (self.published_at || self.created_at) - 2.years
    tags = self.tag_list + self.equipment_list + self.location_list
    Entry.includes(:photos).tagged_with(tags, any: true, order_by_matching_tag_count: true).where('entries.id != ? AND entries.status = ? AND published_at > ?', self.id, 'published', earliest_date).limit(count)
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

    content = if opts[:link_title]
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
    SlackIncomingWebhook.post_all(self) if self.is_published? && self.is_photo? && self.post_to_slack
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
end
