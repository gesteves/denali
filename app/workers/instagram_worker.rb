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

    photos = entry.photos.to_a[0..19].map { |p| { url: p.instagram_url, alt_text: p.alt_text } }

    if photos.size == 1
      # Post a single photo
      instagram.post_photo(
        photo_url: photos.first[:url],
        caption: text,
        alt_text: photos.first[:alt_text]
      )
    else
      # Post as a carousel (2-20 photos)
      instagram.post_carousel(
        photos: photos,
        caption: text
      )
    end

    # Update timestamp if the field exists
    entry.update!(last_shared_on_instagram_at: Time.current)
  end
end

