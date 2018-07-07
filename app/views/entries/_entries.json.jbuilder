json.data do
  json.array! entries do |e|
    json.partial! 'entries/shared/entry', entry: e
    json.links do
      json.self e.permalink_url
      json.prev e.older.permalink_url if e.older.present?
      json.next e.newer.permalink_url if e.newer.present?
    end
  end
end
