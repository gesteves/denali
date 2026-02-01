class InstagramStoryWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  def perform(entry_id, crop = false)
    return if !Rails.env.production?
    return if ENV['INSTAGRAM_APP_ID'].blank? || ENV['INSTAGRAM_APP_SECRET'].blank?

    entry = Entry.find(entry_id)
    return if !entry.is_photo?
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

    instagram.post_story(
      photo_url: photo.instagram_story_url(crop: crop)
    )
  end
end
