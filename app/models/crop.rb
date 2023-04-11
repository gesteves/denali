class Crop < ApplicationRecord
  belongs_to :photo, touch: true, optional: true
  validates :x, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1}
  validates :y, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1}
  validates :width, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1}
  validates :height, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1}
  validates :aspect_ratio, presence: true, uniqueness: { scope: :photo_id }

  def to_rect
    # Retrieve the photo's dimensions
    photo_width = photo.width
    photo_height = photo.height

    # Calculate the absolute pixel coordinates
    left = x * photo_width
    top = y * photo_height
    right = left + (width * photo_width)
    bottom = top + (height * photo_height)

    [left, top, right, bottom].map(&:round)
  end
end
