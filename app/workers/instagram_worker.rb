class InstagramWorker < ApplicationWorker
  sidekiq_options queue: 'high'

  def perform(entry_id, text)
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

    photos = entry.photos.to_a[0..9].map { |p| { url: p.instagram_url, alt_text: p.alt_text } }
    location_id = entry.photos.first.instagram_location_id

    container_id = if photos.size == 1
      instagram.create_photo_container(
        photo_url: photos.first[:url],
        caption: text,
        alt_text: photos.first[:alt_text],
        location_id: location_id
      )
    else
      instagram.create_carousel_container(
        photos: photos,
        caption: text,
        location_id: location_id
      )
    end

    raise "Failed to create Instagram container for entry #{entry_id}: container_id is blank" if container_id.blank?

    InstagramPublishWorker.perform_in(30.seconds, entry_id, container_id)
  end
end

