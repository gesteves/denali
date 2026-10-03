class Park < ApplicationRecord
  include RetagsEntries

  has_many :photos
  validates :slug, presence: true, uniqueness: true
  validates :code, presence: true, uniqueness: true
  validates :full_name, presence: true

  # After commit, or another process could cache the old names again from a
  # transaction that hasn't committed yet.
  after_commit :bust_class_caches, if: :changes_to_fields?

  def self.designations
    Rails.cache.fetch("park/designations", expires_in: 1.hour) do
      where.not(designation: [nil, '']).distinct.pluck(:designation)
    end
  end

  def self.names
    Rails.cache.fetch("park/names", expires_in: 1.hour) do
      where.not(display_name: [nil, '']).distinct.pluck(:display_name)
    end
  end

  def entries_count
    Entry.joins(:photos).where(photos: { park_id: id }).distinct.count
  end

  private

  def retag_entries?
    changes_to_fields?
  end

  def changes_to_fields?
    saved_change_to_display_name? || saved_change_to_designation?
  end

  def bust_class_caches
    Rails.cache.delete("park/designations") if saved_change_to_designation?
    Rails.cache.delete("park/names") if saved_change_to_display_name?
  end
end
