class FacebookJob < BufferJob
  queue_as :default

  def perform(entry)
    text = []
    text << entry.plain_title
    text << entry.plain_body if entry.body.present?
    text << entry.permalink_url
    text = text.join("\n\n")

    media = media_hash(entry.photos.first)
    # Post to facebook profiles
    ids = get_profile_ids('facebook')
    post_to_buffer(ids, text, media)
  end
end
