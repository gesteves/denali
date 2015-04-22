class Entry < ActiveRecord::Base
  has_many :photos, -> { order 'position ASC' }, dependent: :destroy
  belongs_to :blog, touch: true
  belongs_to :user

  validates :title, :body, presence: true

  scope :drafted,   -> { where(status: 'draft').order('published_at DESC') }
  scope :queued,    -> { where(status: 'queued').order('created_at ASC') }
  scope :published, -> { where(status: 'published').order('updated_at ASC') }

  before_save :set_published_date
  before_save :set_entry_slug

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
    self.published_at = Time.now
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
