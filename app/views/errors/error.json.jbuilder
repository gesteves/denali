json.errors do
  json.array! @errors do |e|
    json.status e[:status].to_s
    json.title e[:message]
  end
end
