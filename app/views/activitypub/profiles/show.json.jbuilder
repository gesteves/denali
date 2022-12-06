json.set! '@context', activitypub_profile_context
json.set! 'id', activitypub_profile_url(user_id: @user.id)
json.set! 'type', 'Person'
json.set! 'discoverable', true
json.set! 'manuallyApprovesFollowers', false
json.set! 'name', @user.profile.name if @user.profile.name.present?
json.set! 'preferredUsername', @user.profile.username
json.set! 'published', @user.entries.published.last.published_at
json.set! 'summary', @user.profile.formatted_summary if @user.profile.summary.present?
json.set! 'url', root_url
json.set! 'inbox', activitypub_inbox_url(user_id: @user.id)
json.set! 'outbox', activitypub_outbox_url(user_id: @user.id)
if ENV['PUBLIC_KEY_PEM'].present?
  json.set! 'publicKey' do
    json.set! 'id', "#{activitypub_profile_url(user_id: @user.id)}#main-key"
    json.set! 'owner', activitypub_profile_url(user_id: @user.id)
    json.set! 'publicKeyPem', ENV['PUBLIC_KEY_PEM'].gsub(/\R+/, "\n")
  end
end
if @user.profile.avatar.attached?
  json.set! 'icon' do
    json.set! 'type', 'Image'
    json.set! 'mediaType', 'image/jpeg'
    json.set! 'url', @user.profile.avatar_url
  end
end
if @user.profile.mastodon_banner_url.present?
  json.set! 'image' do
    json.set! 'type', 'Image'
    json.set! 'mediaType', 'image/jpeg'
    json.set! 'url', @user.profile.mastodon_banner_url
    if @user.profile.photo.blurhash.present?
      json.set! 'blurhash', @user.profile.photo.blurhash
    end
  end
end
if attachments.present?
  json.set! 'attachment', attachments
end
