json.set! '@context', ["https://www.w3.org/ns/activitystreams", "https://w3id.org/security/v1"]
json.set! 'id', profile_url(username: @profile.username)
json.set! 'type', 'person'
json.set! 'discoverable', true
json.set! 'name', @profile.name
json.set! 'preferredUsername', @profile.username
json.set! 'published', @profile.created_at
json.set! 'summary', @profile.summary
json.set! 'url', profile_url(username: @profile.username)
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
