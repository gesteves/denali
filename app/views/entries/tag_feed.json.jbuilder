json.cache! [@photoblog, @tag_slug] do
  json.version 'https://jsonfeed.org/version/1'
  json.title "#{@photoblog.name} – #{@tags.first.name}"
  json.home_page_url tag_url(tag: @tag_slug)
  json.feed_url tag_feed_url(format: 'json', tag: @tag_slug)
  json.description "Photos tagged #{@tags.first.name}"
  json.icon @photoblog.touch_icon_url(w: 512) if @photoblog.touch_icon.attached?
  json.favicon @photoblog.favicon_url(w: 64) if @photoblog.favicon.attached?
  json.items @entries do |e|
    json.partial! 'entries/feed/feed_entry', entry: e
  end
end
