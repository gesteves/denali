json.cache! "feed/json/page/#{@page}/#{@photoblog.id}/#{@photoblog.updated_at.to_i}" do
  json.version 'https://jsonfeed.org/version/1'
  if @page.nil? || @page == 1
    json.title @photoblog.name
    json.home_page_url entries_url
    json.feed_url feed_url(format: 'json')
  else
    json.title "#{@photoblog.name} – Page #{@page}"
    json.home_page_url entries_url(page: @page)
    json.feed_url feed_url(format: 'json', page: @page)
  end
  json.description @photoblog.plain_description
  json.icon @photoblog.touch_icon_url(w: 512) if @photoblog.touch_icon.present?
  json.favicon @photoblog.favicon_url if @photoblog.favicon.present?
  json.items @entries do |e|
    json.partial! 'feed_entry', entry: e
  end
end
