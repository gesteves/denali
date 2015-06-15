json.cache! "entries/tagged/json/#{@tag_slug}/#{@photoblog.id}/#{@photoblog.updated_at.to_i}" do
  json.entries @entries do |e|
    json.(e, :title)
    json.url permalink_url e
    json.photos e.photos do |p|
      json.url p.original_url
    end
  end
end
