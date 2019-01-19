class PublishSchedule < ApplicationRecord
  belongs_to :blog, touch: true, counter_cache: true, optional: true

  validates :weekday, uniqueness: { scope: :hour, message: "can't have duplicate publish times" }
end
