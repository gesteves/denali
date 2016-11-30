json.cache! "#{@cache_version}/entries/tagged/json/#{@tag_slug}/page/#{@page}/count/#{@count}/#{@photoblog.id}/#{@photoblog.updated_at.to_i}" do
  json.links do
    json.self @page == 1 ? tag_url(@tag_slug) : tag_url(@tag_slug, @page)
    if @page > 1
      json.prev (@page - 1) == 1 ? tag_url(@tag_slug) : tag_url(@tag_slug, @page - 1)
    end
    json.next tag_url(@tag_slug, @page + 1)
  end
  json.partial! 'entries', entries: @entries
end
