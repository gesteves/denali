json.entries @entries do |e|
  json.(e, :title)
  json.url permalink(e, { path_only: false })
  json.photos e.photos do |p|
    json.url p.original_url
  end
end
