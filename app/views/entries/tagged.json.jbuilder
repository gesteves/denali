json.cache! [@photoblog, @tag_slug, @page, @count]do
  json.links do
    json.self @page == 1 ? tag_url(@tag_slug, page: nil) : tag_url(@tag_slug, @page)
    if @page > 1
      json.prev (@page - 1) == 1 ? tag_url(@tag_slug, page: nil) : tag_url(@tag_slug, @page - 1)
    end
    json.next tag_url(@tag_slug, @page + 1)
  end
  json.partial! 'entries', entries: @entries
end
