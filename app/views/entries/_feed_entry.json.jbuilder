json.cache! "feed/json/entry/#{entry.id}/#{entry.updated_at.to_i}" do
  json.id entry.permalink_url
  json.url entry.permalink_url
  json.title entry.plain_title if entry.title.present?
  json.content_html json.partial! 'feed_entry_body.html.erb', entry: entry
  json.image entry.photos.first.url(w: 1280)
  json.date_published entry.published_at.strftime('%Y-%m-%dT%H:%M:%S%:z')
  json.date_modified entry.modified_at.strftime('%Y-%m-%dT%H:%M:%S%:z')
  json.tags entry.combined_tags.map(&:name)
  json.author do
    json.name entry.user.name
  end
end
