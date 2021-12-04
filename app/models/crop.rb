class Crop < ApplicationRecord
  belongs_to :photo, touch: true, optional: true
  validates :x, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1}
  validates :y, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1}
  validates :width, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1}
  validates :height, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1}
  validates :aspect_ratio, presence: true, uniqueness: { scope: :photo_id }

  def computed_width
    (self.width * photo.width).round
  end

  def computed_height
    (self.height * photo.height).round
  end

  def computed_x
    (self.x * photo.width).round
  end

  def computed_y
    (self.y * photo.height).round
  end

  def to_rect
    [self.computed_x, self.computed_y, self.computed_width, self.computed_height].join(',')
  end
end
