json.cache! [@photoblog, @tag_slug, @page, @count] do
  json.version 'https://jsonfeed.org/version/1'
  if @page.nil? || @page == 1
    json.title "#{@photoblog.name} – #{@tags.first.name}"
    json.home_page_url tag_url(tag: @tag_slug, page: nil)
    json.feed_url tag_feed_url(format: 'json', tag: @tag_slug, page: nil)
  else
    json.title "#{@photoblog.name} – #{@tags.first.name} – Page #{@page}"
    json.home_page_url tag_url(tag: @tag_slug, page: @page)
    json.feed_url tag_feed_url(format: 'json', tag: @tag_slug, page: @page)
  end
  json.description "Photos tagged #{@tags.first.name}"
  json.icon @photoblog.touch_icon_url(w: 512) if @photoblog.touch_icon.attached?
  json.favicon @photoblog.favicon_url(w: 64) if @photoblog.favicon.attached?
  json.items @entries do |e|
    json.partial! 'feed_entry', entry: e
  end
end
