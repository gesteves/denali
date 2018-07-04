json.cache! "feed/json/page/#{@page}/count/#{@count}/#{@photoblog.cache_key}" do
  json.version 'https://jsonfeed.org/version/1'
  if @page.nil? || @page == 1
    json.title @photoblog.name
    json.home_page_url root_url
    json.feed_url feed_url(format: 'json', page: nil)
  else
    json.title "#{@photoblog.name} – Page #{@page}"
    json.home_page_url entries_url(page: @page)
    json.feed_url feed_url(format: 'json', page: @page)
  end
  json.description @photoblog.plain_description
  json.icon @photoblog.touch_icon_url(w: 512) if @photoblog.touch_icon.attached?
  json.favicon @photoblog.favicon_url(w: 64) if @photoblog.favicon.attached?
  json.items @entries do |e|
    json.partial! 'feed_entry', entry: e
  end
end
