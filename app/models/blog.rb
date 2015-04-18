class Blog < ActiveRecord::Base
  validates :name, presence: true
  validates :photo_quality, presence: true, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 }
end
