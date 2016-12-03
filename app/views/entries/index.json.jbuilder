json.cache! "#{@cache_version}/entries/json/page/#{@page}/count/#{@count}/#{@photoblog.id}/#{@photoblog.updated_at.to_i}" do
  json.links do
    json.self @page == 1 ? entries_url : entries_url(@page)
    if @page > 1
      json.prev (@page - 1) == 1 ? entries_url : entries_url(@page - 1)
    end
    json.next entries_url(@page + 1)
  end
  json.partial! 'entries', entries: @entries
end
