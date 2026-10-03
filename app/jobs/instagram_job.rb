# Posts an entry to the Instagram feed. See MetaShareJob for how the post is made.
class InstagramJob < MetaShareJob
  MAX_PHOTOS = Instagram::MAX_CAROUSEL_PHOTOS

  def self.available_for?(user)
    ENV['INSTAGRAM_APP_ID'].present? && ENV['INSTAGRAM_APP_SECRET'].present? && user&.instagram_account.present?
  end

  private

  def network
    'Instagram'
  end

  def build_client(user)
    Instagram.new(
      app_id: ENV['INSTAGRAM_APP_ID'],
      app_secret: ENV['INSTAGRAM_APP_SECRET'],
      social_account: user.instagram_account
    )
  end

  def photo_url(photo)
    photo.instagram_url
  end

  def create_single_container(client, entry, photo, text)
    client.create_media_container(image_url: photo_url(photo), caption: text, alt_text: photo.alt_text,
                                  location_id: photo.instagram_location_id)
  end

  def create_carousel_container(client, entry, children, text)
    client.create_carousel_container(children: children, caption: text, location_id: entry.photos.first.instagram_location_id)
  end

  # Hashtags go in the first comment rather than the caption. Without the post's media ID (the
  # response that held it never arrived) there's nothing to comment on.
  def after_publish(entry, media_id)
    return if media_id.blank? || @state['commented']

    InstagramCommentJob.perform_async(entry.id, media_id) if entry.instagram_hashtags.present?
    save_state('commented' => true)
  end
end
