class PublishSchedule < ApplicationRecord
  belongs_to :blog, touch: true, counter_cache: true, optional: true

  validates :hour, uniqueness: true
end
