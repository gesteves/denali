json.set! '@context', activitypub_activitystream_context
json.partial! 'activitypub/shared/entry', entry: @entry, user: @user
