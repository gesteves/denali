class PublishSchedule < ApplicationRecord
  belongs_to :blog, touch: true, counter_cache: true, optional: true

  validates :hour, uniqueness: true
  
  after_save :touch_blog
  before_destroy :touch_blog
  
  def touch_blog
    self.blog.touch
  end
end
