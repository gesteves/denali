class Territory < ApplicationRecord
  has_many :photo_territories, dependent: :destroy
  has_many :photos, through: :photo_territories

  validates :slug, presence: true, uniqueness: true
  validates :name, presence: true
end
