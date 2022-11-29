json.set! '@context', activitypub_profile_context
json.set! 'id', activitypub_profile_url(username: @profile.username)
json.set! 'type', 'Person'
json.set! 'discoverable', true
json.set! 'manuallyApprovesFollowers', false
json.set! 'name', @profile.name if @profile.name.present?
json.set! 'preferredUsername', @profile.username
json.set! 'published', @profile.user.entries.published.last.published_at
json.set! 'summary', @profile.summary if @profile.summary.present?
json.set! 'url', profile_url(username: @profile.username)
json.set! 'inbox', activitypub_inbox_url(username: @profile.username)
json.set! 'outbox', activitypub_outbox_url(username: @profile.username)
if @photoblog.public_key.present?
  json.set! 'publicKey' do
    json.set! 'id', "#{activitypub_profile_url(username: @profile.username)}#main-key"
    json.set! 'owner', activitypub_profile_url(username: @profile.username)
    json.set! 'publicKeyPem', @photoblog.public_key.gsub(/\R+/, "\n")
  end
end
if @profile.avatar.attached?
  json.set! 'icon' do
    json.set! 'type', 'Image'
    json.set! 'mediaType', 'image/jpeg'
    json.set! 'url', @profile.avatar_url
  end
end
if @profile.mastodon_banner_url.present?
  json.set! 'image' do
    json.set! 'type', 'Image'
    json.set! 'mediaType', 'image/jpeg'
    json.set! 'url', @profile.mastodon_banner_url
    if @profile.photo.blurhash.present?
      json.set! 'blurhash', @profile.photo.blurhash
    end
  end
end
if attachments.present?
  json.set! 'attachment', attachments
end
