json.set! 'id', activitypub_entry_url(user_id: user.id, entry_id: entry.id)
json.set! 'url', entry.permalink_url
json.set! 'type', 'Note'
json.set! 'published', entry.published_at
json.set! 'attributedTo', activitypub_profile_url(user_id: user.id)
json.set! 'to', ["https://www.w3.org/ns/activitystreams#Public"]
json.set! 'atomUri', activitypub_entry_url(user_id: user.id, entry_id: entry.id)
json.set! 'inReplyToAtomUri', nil
json.set! 'inReplyTo', nil
json.set! 'sensitive', entry.is_sensitive?
json.set! 'summary', entry.content_warning.presence
json.set! 'content', render(partial: 'activitypub/shared/entry/body', formats: :html, object: entry, as: :entry).to_str.gsub(/\R+/, '').gsub(/\s+/, ' ').strip
json.attachment entry.photos do |photo|
  json.set! 'type', 'Image'
  json.set! 'mediaType', 'image/jpeg'
  json.set! 'url', photo.mastodon_url
  if photo.alt_text.present?
    json.set! 'summary', photo.alt_text
  end
  if photo.mastodon_focal_point.present?
    json.set! 'focalPoint', photo.mastodon_focal_point
  end
  if photo.blurhash.present?
    json.set! 'blurhash', photo.blurhash
  end
end
json.tag entry.combined_tags do |tag|
  json.set! 'type', 'Hashtag'
  json.set! 'name', "##{tag.name.parameterize.split('-').map(&:titleize).join}"
  json.set! 'href', tag_url(tag.slug, page: nil)
end
