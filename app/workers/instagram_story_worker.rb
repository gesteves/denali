class InstagramStoryWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  def perform(entry_id)
    return if !Rails.env.production?
    return if ENV['INSTAGRAM_APP_ID'].blank? || ENV['INSTAGRAM_APP_SECRET'].blank? || ENV['INSTAGRAM_ACCESS_TOKEN'].blank? || ENV['INSTAGRAM_ACCOUNT_ID'].blank?
    entry = Entry.published.find(entry_id)
    return if !entry.is_photo?
    raise UnprocessedPhotoError unless entry.photos_have_dimensions?

    instagram = Instagram.new(
      app_id: ENV['INSTAGRAM_APP_ID'],
      app_secret: ENV['INSTAGRAM_APP_SECRET'],
      ig_account_id: ENV['INSTAGRAM_ACCOUNT_ID']
    )

    # Stories only support single photos, use the first photo
    photo = entry.photos.first
    return if photo.blank?

    instagram.post_story(
      photo_url: photo.instagram_story_url
    )
  end
end

