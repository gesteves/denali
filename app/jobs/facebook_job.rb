class FacebookJob < BufferJob
  queue_as :default

  def perform(entry)
    text = []
    text << entry.plain_title
    text << entry.plain_body if entry.body.present?
    text << entry.permalink_url(utm_source: 'facebook.com', utm_medium: 'social')
    image_url = entry.photos.first.url(w: 2048, fm: 'jpg')
    thumbnail_url = entry.photos.first.url(w: 512, fm: 'jpg')

    # Post to facebook profiles
    ids = get_profile_ids('facebook')
    post_to_buffer(ids, text.join("\n\n"), image_url, thumbnail_url)

    # Add tags for facebook page
    text << entry.combined_tags.map { |t| "##{t.slug.gsub(/-/, '')}" }.join(' ')

    # Post to facebook pages
    ids = get_profile_ids('facebook', 'page')
    post_to_buffer(ids, text.join("\n\n"), image_url, thumbnail_url)
  end
end
