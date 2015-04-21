class Entry < ActiveRecord::Base
  has_many :photos, -> { order 'position ASC' }, dependent: :destroy
  belongs_to :blog, touch: true
  belongs_to :user

  validates :title, :body, presence: true

  scope :published, -> { where(published: true).order('published_at DESC') }
  scope :queued, -> { where(queued: true).order('created_at ASC') }
  scope :drafted, -> { where(draft: true).order('updated_at ASC') }

  def publish
    self.published = true
    self.draft = false
    self.queued = false
    self.published_at = Time.now
    self.save!
  end
end
