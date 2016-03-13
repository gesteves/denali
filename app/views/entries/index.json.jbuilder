json.cache! "entries/json/page/#{@page}/count/#{@count}/#{@photoblog.id}/#{@photoblog.updated_at.to_i}" do
  json.links do
    json.self entries_url(@page)
    json.prev entries_url(@page - 1) unless @page == 1
    json.next entries_url(@page + 1)
  end
  json.partial! 'entries', entries: @entries
end
