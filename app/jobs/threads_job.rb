# Posts an entry to Threads. See MetaShareJob for how the post is made.
class ThreadsJob < MetaShareJob
  MAX_PHOTOS = Threads::MAX_CAROUSEL_PHOTOS

  def self.available_for?(user)
    ENV['THREADS_APP_ID'].present? && ENV['THREADS_APP_SECRET'].present? && user&.threads_account.present?
  end

  private

  def network
    'Threads'
  end

  def build_client(user)
    Threads.new(
      app_id: ENV['THREADS_APP_ID'],
      app_secret: ENV['THREADS_APP_SECRET'],
      social_account: user.threads_account
    )
  end

  def photo_url(photo)
    photo.threads_url
  end

  def create_single_container(client, entry, photo, text)
    client.create_media_container(image_url: photo_url(photo), caption: text, alt_text: photo.alt_text,
                                  topic_tag: entry.threads_topic, location_id: photo.threads_location_id)
  end

  def create_carousel_container(client, entry, children, text)
    client.create_carousel_container(children: children, caption: text, topic_tag: entry.threads_topic,
                                     location_id: entry.photos.first.threads_location_id)
  end
end
