# Posts an entry's first photo to Instagram Stories, from the admin.
class InstagramStoryJob < ApplicationJob
  # A story lasts a day, so one still failing after six hours is better dropped than posted late.
  sidekiq_options queue: 'high', retry_for: 6.hours.to_i

  def self.retry_delay(count, exception)
    exception.is_a?(MetaAuthError) ? :discard : super
  end

  def perform(entry_id, crop = false)
    return if !Rails.env.production?
    return if ENV['INSTAGRAM_APP_ID'].blank? || ENV['INSTAGRAM_APP_SECRET'].blank?

    entry = Entry.find_by(id: entry_id)
    return if entry.nil? || !entry.is_photo?
    raise UnprocessedPhotoError unless entry.photos_have_dimensions?

    instagram_account = entry.user.instagram_account
    return if instagram_account.blank?

    instagram = Instagram.new(
      app_id: ENV['INSTAGRAM_APP_ID'],
      app_secret: ENV['INSTAGRAM_APP_SECRET'],
      social_account: instagram_account
    )

    # Stories only support single photos, so use the first photo
    photo = entry.photos.first
    return if photo.blank?

    story_url = photo.instagram_story_url(crop: crop)
    photo.warm_cache(story_url)

    instagram.post_story(
      photo_url: story_url
    )
  end
end
