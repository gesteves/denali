json.set! 'id', activitypub_activity_url(user_id: user.id, activity_id: entry.id)
json.set! 'type', 'Create'
json.set! 'actor', activitypub_profile_url(user_id: user.id)
json.set! 'published', entry.published_at
json.set! 'to', ["as:Public"]
json.set! 'object' do
  json.partial! 'activitypub/shared/entry', entry: entry, user: user
end
