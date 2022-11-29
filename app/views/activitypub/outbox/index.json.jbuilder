json.set! '@context', "https://www.w3.org/ns/activitystreams"
json.set! 'id', activitypub_outbox_url(username: @profile.username)
json.set! 'type', 'OrderedCollection'
json.set! 'totalItems', @total_entries
json.set! 'first', activitypub_outbox_activities_url(username: @profile.username, page: 1)
json.set! 'last', activitypub_outbox_activities_url(username: @profile.username, page: @total_pages)

