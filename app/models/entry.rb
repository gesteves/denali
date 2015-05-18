class Entry < ActiveRecord::Base
  include Formattable

  has_many :photos, -> { order 'position ASC' }, dependent: :destroy
  belongs_to :blog, touch: true
  belongs_to :user

  validates :title, presence: true

  scope :drafted,   -> { where(status: 'draft').order('updated_at DESC') }
  scope :queued,    -> { where(status: 'queued').order('position ASC') }
  scope :published, -> { where(status: 'published').order('published_at DESC') }
  scope :text_entries, -> { where('photos_count = 0') }
  scope :photo_entries, -> { where('photos_count > 0') }

  before_save :set_published_date, if: :is_published?
  before_save :set_entry_slug

  acts_as_taggable
  acts_as_list scope: :blog

  accepts_nested_attributes_for :photos, allow_destroy: true, reject_if: lambda { |attributes| attributes['source_file'].blank? && attributes['source_url'].blank? && attributes['id'].blank? }

  def is_photo?
    self.photos_count > 0
  end

  def is_photoset?
    self.photos_count > 1
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

  def update_position
    if self.is_queued? && self.position.nil?
      self.insert_at(Entry.last_queued_position + 1)
    elsif self.is_published? || self.is_draft?
      self.remove_from_list
    end
  end

  def formatted_body
    markdown_to_html(self.body)
  end

  def plain_body
    markdown_to_plaintext(self.body)
  end

  def formatted_title
    smartypants(self.title)
  end

  def self.last_queued_position
    queue = Entry.queued
    if queue.blank? || queue.last.position.nil?
      0
    else
      queue.last.position
    end
  end

  private

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
