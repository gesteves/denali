json.set! 'id', activitypub_activity_url(username: profile.username, id: entry.id)
json.set! 'type', 'Create'
json.set! 'actor', activitypub_profile_url(username: profile.username)
json.set! 'published', entry.published_at
json.set! 'to', ["https://www.w3.org/ns/activitystreams#Public"]
json.set! 'object' do
  json.partial! 'activitypub/shared/entry', entry: entry, profile: profile
end
