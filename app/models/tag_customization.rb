class TagCustomization < ApplicationRecord
  validate :tag_list_must_be_unique, :hashtags_and_groups_cannot_be_blank
  validates :tag_list, presence: true
  belongs_to :blog, touch: true, optional: true
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

  private

  def tag_list_must_be_unique
    tag_customizations = TagCustomization.where.not(id: self.id).tagged_with(self.tag_list, :match_all => true)
    if tag_customizations.any? { |tc| tc.tag_list.size == self.tag_list.size }
      errors.add(:tag_list, "already exists")
    end
  end

  def hashtags_and_groups_cannot_be_blank
    if self.instagram_hashtags.blank? && self.flickr_groups.blank?
      errors.add(:base, 'Instagram hashtags and Flickr groups cannot be both empty')
    end
  end
end
