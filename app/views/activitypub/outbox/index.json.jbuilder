json.set! '@context', "https://www.w3.org/ns/activitystreams"
json.set! 'id', activitypub_outbox_url(username: @profile.username)
json.set! 'type', 'OrderedCollection'
json.set! 'totalItems', @total_entries
if @first_page.present?
  json.set! 'first', @first_page
end
if @last_page.present?
  json.set! 'last', @last_page
end

