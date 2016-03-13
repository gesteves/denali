json.cache! "entries/tagged/json/#{@tag_slug}/page/#{@page}/count/#{@count}/#{@photoblog.id}/#{@photoblog.updated_at.to_i}" do
  json.links do
    json.self tag_url(@tag_slug, @page)
    json.prev tag_url(@tag_slug, @page - 1) unless @page == 1
    json.next tag_url(@tag_slug, @page + 1)
  end
  json.partial! 'entries', entries: @entries
end
