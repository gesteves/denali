json.set! '@context', activitypub_activitystream_context
json.set! 'id', @current_page
json.set! 'type', 'OrderedCollectionPage'
json.set! 'partOf', activitypub_outbox_url(user_id: @user.id)
unless @page == 1
  json.set! 'next', activitypub_outbox_activities_url(user_id: @user.id, page: @page - 1)
end
unless @page == @total_pages
  json.set! 'prev', activitypub_outbox_activities_url(user_id: @user.id, page: @page + 1)
end
json.orderedItems @entries do |entry|
  json.partial! 'activitypub/shared/activity', entry: entry, user: @user
end
