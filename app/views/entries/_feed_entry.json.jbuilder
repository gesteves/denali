json.cache! "feed/json/entry/#{entry.id}/#{entry.updated_at.to_i}" do
  json.id entry.permalink_url
  json.url entry.permalink_url
  json.title entry.plain_title if entry.title.present?
  json.content_html entry.photos.map { |p| image_tag(p.url(w: 1280), srcset: "#{p.url(w: 1280)} 1x, #{p.url(w: 2560)} 2x", alt: p.caption.blank? ? entry.title : p.plain_caption) }.join("\n\n") + entry.formatted_body
  json.image entry.photos.first.url(w: 1280)
  json.date_published entry.published_at.strftime('%Y-%m-%dT%H:%M:%S%:z')
  json.date_modified entry.updated_at.strftime('%Y-%m-%dT%H:%M:%S%:z')
  json.tags entry.tags.map(&:name)
  json.author do
    json.name entry.user.name
  end
end
