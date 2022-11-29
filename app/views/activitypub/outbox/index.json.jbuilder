json.set! '@context', "https://www.w3.org/ns/activitystreams"
json.set! 'id', activitypub_outbox_url(user_id: @user.id)
json.set! 'type', 'OrderedCollection'
json.set! 'totalItems', @total_entries
json.set! 'first', activitypub_outbox_activities_url(user_id: @user.id, page: 1)
json.set! 'last', activitypub_outbox_activities_url(user_id: @user.id, page: @total_pages)

