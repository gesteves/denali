class Crop < ApplicationRecord
  belongs_to :photo, touch: true, optional: true
  validates :x, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1}
  validates :y, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1}
  validates :width, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1}
  validates :height, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1}
  validates :name, presence: true, uniqueness: { scope: :photo_id }
end
