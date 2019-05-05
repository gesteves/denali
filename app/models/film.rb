class Film < ApplicationRecord
  has_many :photos
  validates :slug, presence: true, uniqueness: true
  validates :make, presence: true
  validates :model, presence: true
  validates :display_name, presence: true

  after_save :update_entry_tags, if: :saved_change_to_display_name?

  def update_entry_tags
    self.photos.map { |p| p.entry.update_tags }
  end
end
