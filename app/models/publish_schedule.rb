class PublishSchedule < ApplicationRecord
  belongs_to :blog, touch: true, counter_cache: true, optional: true

  validates :hour, uniqueness: true
  
  after_save :touch_entries
  before_destroy :touch_entries
  
  def touch_entries
    self.blog.entries.queued.each(&:touch)
  end
end
