json.set! '@context', activitypub_activitystream_context
json.partial! 'activitypub/shared/activity', entry: @entry, user: @user
