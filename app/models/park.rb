class Park < ApplicationRecord
  has_many :photos
  validates :slug, presence: true, uniqueness: true
  validates :code, presence: true, uniqueness: true
  validates :full_name, presence: true

  after_save :update_entry_tags, if: :saved_change_to_full_name?

  def update_entry_tags
    self.photos.map { |p| p.entry.update_tags }
  end

  def self.designations
    Park.all.map(&:designation).reject(&:blank?).uniq
  end
end
