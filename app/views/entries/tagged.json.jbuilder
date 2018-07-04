json.cache! "entries/json/tagged/#{@tag_slug}/page/#{@page}/count/#{@count}/#{@photoblog.cache_key}" do
  json.links do
    json.self @page == 1 ? tag_url(@tag_slug, page: nil) : tag_url(@tag_slug, @page)
    if @page > 1
      json.prev (@page - 1) == 1 ? tag_url(@tag_slug, page: nil) : tag_url(@tag_slug, @page - 1)
    end
    json.next tag_url(@tag_slug, @page + 1)
  end
  json.partial! 'entries', entries: @entries
end
