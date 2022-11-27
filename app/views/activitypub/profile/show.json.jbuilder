json.set! '@context', json_context
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
if @profile.public_key.present?
  json.set! 'publicKey' do
    json.set! 'id', "#{activitypub_profile_url(username: @profile.username)}#main-key"
    json.set! 'owner', activitypub_profile_url(username: @profile.username)
    json.set! 'publicKeyPem', @profile.public_key.gsub(/\R+/, "\n")
  end
end
if @profile.avatar.attached?
  json.set! 'icon' do
    json.set! 'type', 'Image'
    json.set! 'mediaType', 'image/jpeg'
    json.set! 'url', @profile.avatar_url
  end
end
if @profile.banner_url.present?
  json.set! 'image' do
    json.set! 'type', 'Image'
    json.set! 'mediaType', 'image/jpeg'
    json.set! 'url', @profile.banner_url
  end
end
if attachments.present?
  json.set! 'attachment', attachments
end
