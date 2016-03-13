json.cache! "entry/json/#{@entry.id}/#{@entry.updated_at.to_i}" do
  json.links do
    json.self @entry.permalink_url
    json.prev @entry.older.permalink_url if @entry.older.present?
    json.next @entry.newer.permalink_url if @entry.newer.present?
  end
  json.data do
    json.partial! 'entry', entry: @entry
  end
end
