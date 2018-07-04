json.cache! "entries/json/page/#{@page}/count/#{@count}/#{@photoblog.cache_key}" do
  json.links do
    json.self @page == 1 ? entries_url(page: nil) : entries_url(@page)
    if @page > 1
      json.prev (@page - 1) == 1 ? entries_url(page: nil) : entries_url(@page - 1)
    end
    json.next entries_url(@page + 1)
  end
  json.partial! 'entries', entries: @entries
end
