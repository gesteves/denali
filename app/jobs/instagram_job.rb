class InstagramJob < ApplicationJob
  sidekiq_options queue: 'high'

  # @param text [String, nil] the caption. Without one, the job builds the entry's
  #   caption when it runs rather than when it was enqueued, so an entry
  #   published straight from the form gets the tags and EXIF details that are
  #   only filled in after it's saved.
  def perform(entry_id, text = nil)
    return if !Rails.env.production?
    return if ENV['INSTAGRAM_APP_ID'].blank? || ENV['INSTAGRAM_APP_SECRET'].blank?

    entry = Entry.published.find(entry_id)
    return if !entry.is_photo?
    raise UnprocessedPhotoError unless entry.photos_have_dimensions?

    instagram_account = entry.user.instagram_account
    return if instagram_account.blank?

    text ||= entry.instagram_caption
    instagram = Instagram.new(
      app_id: ENV['INSTAGRAM_APP_ID'],
      app_secret: ENV['INSTAGRAM_APP_SECRET'],
      social_account: instagram_account
    )

    photos = entry.photos.limit(10).map { |p| { url: p.instagram_url, alt_text: p.alt_text } }
    location_id = entry.photos.first.instagram_location_id

    entry.photos.limit(10).each { |p| p.warm_cache(p.instagram_url) }

    response = instagram.post(
      photos: photos,
      caption: text,
      location_id: location_id
    )
    entry.update_columns(
      last_shared_on_instagram_at: Time.current,
      instagram_shares_count: entry.instagram_shares_count + 1
    )

    instagram_post_id = response['id']
    InstagramCommentJob.perform_async(entry_id, instagram_post_id) if instagram_post_id.present? && entry.instagram_hashtags.present?
  end
end
