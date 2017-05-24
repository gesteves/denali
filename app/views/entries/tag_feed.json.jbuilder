json.cache! "feed/json/#{@photoblog.id}/#{@photoblog.updated_at.to_i}" do
  json.version 'https://jsonfeed.org/version/1'
  json.title "#{@photoblog.name} - #{@tags.first.name.titlecase}"
  json.home_page_url root_url
  json.feed_url feed_url(format: 'json', tag: @tag_slug)
  json.description "Photos tagged #{@tags.first.name.titlecase}"
  json.icon @photoblog.touch_icon_url(w: 512) if @photoblog.touch_icon.present?
  json.favicon @photoblog.favicon_url if @photoblog.favicon.present?
  json.items @entries do |e|
    json.id e.permalink_url
    json.url e.permalink_url
    json.title e.plain_title if e.title.present?
    json.content_html e.photos.map { |p| image_tag(p.url(w: 1280), alt: p.caption.blank? ? e.title : p.plain_caption) }.join("\n\n") + e.formatted_body
    json.image e.photos.first.url(w: 1280)
    json.date_published e.published_at.strftime('%Y-%m-%dT%H:%M:%S%:z')
    json.date_modified e.updated_at.strftime('%Y-%m-%dT%H:%M:%S%:z')
    json.tags e.tags.map(&:name)
    json.author do
      json.name e.user.name
    end
  end
end
