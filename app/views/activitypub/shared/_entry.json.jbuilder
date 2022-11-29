json.set! 'id', activitypub_entry_url(user_id: user.id, entry_id: entry.id)
json.set! 'type', 'Note'
json.set! 'summary', nil
json.set! 'inReplyTo', nil
json.set! 'published', entry.published_at
json.set! 'url', entry.permalink_url
json.set! 'attributedTo', activitypub_profile_url(user_id: user.id)
json.set! 'to', ["as:Public"]
json.set! 'sensitive', false
json.set! 'atomUri', activitypub_entry_url(user_id: user.id, entry_id: entry.id)
json.set! 'inReplyToAtomUri', nil
json.set! 'content', entry.activitypub_caption
json.attachment entry.photos do |photo|
  json.set! 'type', 'Image'
  json.set! 'mediaType', 'image/jpeg'
  json.set! 'url', photo.activitypub_url
  if photo.alt_text.present?
    json.set! 'summary', photo.alt_text
  end
  if photo.activitypub_focal_point.present?
    json.set! 'focalPoint', photo.activitypub_focal_point
  end
  json.set! 'blurhash', photo.blurhash
end
json.tag entry.combined_tags do |tag|
  json.set! 'type', 'Hashtag'
  json.set! 'name', "##{tag.name.parameterize.split('-').map(&:titleize).join}"
  json.set! 'href', tag_url(tag.slug)
end
