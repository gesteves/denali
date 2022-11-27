json.set! '@context', ["https://www.w3.org/ns/activitystreams", "https://w3id.org/security/v1"]
json.set! 'id', activitypub_profile_url(username: @profile.username)
json.set! 'type', 'person'
json.set! 'discoverable', true
json.set! 'name', @profile.name
json.set! 'preferredUsername', @profile.username
json.set! 'published', @profile.created_at
json.set! 'summary', @profile.summary
json.set! 'url', activitypub_profile_url(username: @profile.username)
json.set! 'inbox', activitypub_inbox_url(username: @profile.username)
json.set! 'outbox', activitypub_outbox_url(username: @profile.username)
if @profile.public_key.present?
  json.set! 'publicKey' do
    json.set! 'id', "#{activitypub_profile_url(username: @profile.username)}#main-key"
    json.set! 'owner', activitypub_profile_url(username: @profile.username)
    json.set! 'publicKeyPem', @profile.public_key.gsub(/\R+/, "\n")
  end
end
json.set! 'icon' do
  json.set! 'type', 'image'
  json.set! 'mediaType', 'image/jpeg'
  json.set! 'url', @profile.avatar_url
end
json.set! 'image' do
  json.set! 'type', 'image'
  json.set! 'mediaType', 'image/jpeg'
  json.set! 'url', @profile.banner_url
end
