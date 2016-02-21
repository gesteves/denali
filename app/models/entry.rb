class Entry < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  include Formattable

  has_many :photos, -> { order 'position ASC' }, dependent: :destroy
  belongs_to :blog, touch: true
  belongs_to :user

  validates :title, presence: true

  scope :text_entries, -> { where('photos_count = 0') }
  scope :photo_entries, -> { where('photos_count > 0') }

  before_save :set_published_date, if: :is_published?
  before_save :set_entry_slug

  acts_as_taggable
  acts_as_list scope: :blog

  accepts_nested_attributes_for :photos, allow_destroy: true, reject_if: lambda { |attributes| attributes['source_file'].blank? && attributes['source_url'].blank? && attributes['id'].blank? }

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
    where(show_in_map: true)
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

  def newer
    Entry.published('published_at ASC').where('published_at > ?', self.published_at).limit(1).first
  end

  def older
    Entry.published.where('published_at < ?', self.published_at).limit(1).first
  end

  def related(count = 12)
    Entry.includes(:photos).tagged_with(self.tag_list, any: true, order_by_matching_tag_count: true).where('entries.id != ? AND entries.status = ?', self.id, 'published').limit(count)
  end

  def update_position
    if self.is_queued?
      self.insert_at(Entry.last_queued_position + 1)
    else
      self.remove_from_list
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

  def formatted_content
    content = self.title
    content += "\n\n#{self.body}" unless self.body.blank?
    markdown_to_html(content)
  end

  def self.last_queued_position
    queue = Entry.queued
    if queue.blank? || queue.last.position.nil?
      0
    else
      queue.last.position
    end
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

  def permalink_url
    year, month, day, id, slug = self.slug_params
    entry_long_url(year, month, day, id, slug, url_opts(self.blog.domain))
  end

  def short_permalink_url
    entry_url(self.id, url_opts(self.blog.short_domain))
  end

  private

  def url_opts(domain)
    if Rails.env.production?
      {
        protocol: Rails.configuration.force_ssl ? 'https' : 'http',
        host: domain
      }
    else
      {
        only_path: true
      }
    end
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
