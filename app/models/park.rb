class Park < ApplicationRecord
  has_many :photos
  validates :slug, presence: true, uniqueness: true
  validates :code, presence: true, uniqueness: true
  validates :full_name, presence: true

  after_save :update_entry_tags, if: :changes_to_fields?

  def update_entry_tags
    self.photos.map { |p| p.entry.update_tags }
  end

  def self.designations
    Park.all.map(&:designation).reject(&:blank?).uniq
  end

  def self.names
    Park.all.map(&:display_name).reject(&:blank?).uniq
  end

  private

  def changes_to_fields?
    saved_change_to_display_name? || saved_change_to_designation?
  end
end
