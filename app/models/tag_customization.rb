class TagCustomization < ApplicationRecord
  validate :fields_cannot_be_blank
  validates :tag_list, presence: true
  belongs_to :blog, touch: true, optional: true
  acts_as_taggable_on :tags

  before_save :cleanup_hashtags
  before_save :cleanup_flickr_albums
  before_save :cleanup_threads_topics
  after_save :cleanup_flickr_groups, if: :saved_change_to_flickr_groups?
  before_create :merge_existing_tag_customization

  def bluesky_hashtags_to_a
    return [] if self.bluesky_hashtags.blank?
    self.bluesky_hashtags.split(/\s+/)
  end

  def mastodon_hashtags_to_a
    return [] if self.mastodon_hashtags.blank?
    self.mastodon_hashtags.split(/\s+/)
  end

  def instagram_hashtags_to_a
    return [] if self.instagram_hashtags.blank?
    self.instagram_hashtags.split(/\s+/)
  end

  def flickr_groups_to_a
    return [] if self.flickr_groups.blank?
    self.flickr_groups.split(/\s+/)
  end

  def flickr_albums_to_a
    return [] if self.flickr_albums.blank?
    self.flickr_albums.split(/\s+/)
  end

  def threads_topics_to_a
    return [] if self.threads_topics.blank?
    self.threads_topics.split(/\r?\n/).reject(&:blank?)
  end

  def flickr_groups_slugs
    self.flickr_groups_to_a.map { |g| g.split('/').last }
  end

  def matches_tags?(tags)
    self.tags.all? { |t| tags.include? t }
  end

  def cleanup_flickr_albums
    self.flickr_albums = self.flickr_albums
                              &.split(/\s+/)
                              &.uniq
                              &.sort
                              &.join("\n")
  end

  def cleanup_hashtags
    self.bluesky_hashtags = self.bluesky_hashtags
                                    &.split(/\s+/)
                                    &.map { |h| convert_to_hashtag(h) }
                                    &.reject(&:blank?)
                                    &.uniq
                                    &.sort
                                    &.join("\n")

    self.mastodon_hashtags = self.mastodon_hashtags
                                    &.split(/\s+/)
                                    &.map { |h| convert_to_hashtag(h) }
                                    &.reject(&:blank?)
                                    &.uniq
                                    &.sort
                                    &.join("\n")

    self.instagram_hashtags = self.instagram_hashtags
                                    &.split(/\s+/)
                                    &.map { |h| convert_to_hashtag(h) }
                                    &.reject(&:blank?)
                                    &.uniq
                                    &.sort
                                    &.join("\n")
  end

  def cleanup_flickr_groups
    UpdateTagCustomizationWorker.perform_async(self.id)
  end

  def cleanup_threads_topics
    self.threads_topics = self.threads_topics
                              &.split(/\r?\n/)
                              &.reject(&:blank?)
                              &.uniq
                              &.sort
                              &.join("\n")
  end

  private

  def merge_existing_tag_customization
    existing = TagCustomization.where.not(id: self.id).tagged_with(self.tag_list, match_all: true).first
    return unless existing

    # Merge hashtags
    self.bluesky_hashtags = [self.bluesky_hashtags, existing.bluesky_hashtags].compact.join("\n")
    self.mastodon_hashtags = [self.mastodon_hashtags, existing.mastodon_hashtags].compact.join("\n")
    self.instagram_hashtags = [self.instagram_hashtags, existing.instagram_hashtags].compact.join("\n")
    self.threads_topics = [self.threads_topics, existing.threads_topics].compact.join("\n")
    self.flickr_groups = [self.flickr_groups, existing.flickr_groups].compact.join("\n")
    self.flickr_albums = [self.flickr_albums, existing.flickr_albums].compact.join("\n")

    existing.destroy
  end

  def fields_cannot_be_blank
    if self.bluesky_hashtags.blank? && self.mastodon_hashtags.blank? && self.instagram_hashtags.blank? && self.threads_topics.blank? && self.flickr_groups.blank? && self.flickr_albums.blank?
      errors.add(:base, 'You need to fill out at least one of the fields')
    end
  end

  def convert_to_hashtag(text)
    return if text.blank?
    "##{text.gsub(/[^a-zA-Z0-9]/, '')}"
  end
end
