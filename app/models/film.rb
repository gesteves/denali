class Film < ApplicationRecord
  has_many :photos
  validates :slug, presence: true, uniqueness: true
  validates :make, presence: true
  validates :model, presence: true
  validates :display_name, presence: true
end
