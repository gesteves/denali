class Lens < ApplicationRecord
  has_many :photos
  validates :slug, uniqueness: true
end
