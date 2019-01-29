class PublishSchedule < ApplicationRecord
  belongs_to :blog, touch: true, counter_cache: true, optional: true

  validates :hour, uniqueness: true
  
  after_save :update_blog
  
  def update_blog
    self.blog.touch
  end
end
