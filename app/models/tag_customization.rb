class TagCustomization < ApplicationRecord
  belongs_to :blog, optional: true
  acts_as_taggable_on :tags

  def instagram_hashtags_array
    self.instagram_hashtags.split(/\s+/).reject(&:blank?).map { |h| h.gsub(/^#/, '') }.uniq
  end

  def flickr_groups_array
    self.flickr_groups.split(/\s+/).reject(&:blank?).uniq
  end

  def matches_tags?(tags)
    self.tags.all? { |t| tags.include? t }
  end
end
