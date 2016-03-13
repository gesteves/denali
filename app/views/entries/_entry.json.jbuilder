json.type 'entry'
json.(entry, :id)
json.attributes do
  json.(entry, :title)
  json.(entry, :plain_title)
  json.(entry, :body)
  json.(entry, :formatted_body)
  json.(entry, :plain_body)
  json.(entry, :slug)
  json.(entry, :photos_count)
  json.(entry, :published_at)
  json.(entry, :updated_at)
  json.(entry, :created_at)
end
json.relationships do
  json.photos do
    json.data do
      json.array! entry.photos do |p|
        json.type 'photo'
        json.(p, :id)
        json.attributes do
          json.(p, :caption)
          json.(p, :formatted_caption)
          json.(p, :plain_caption)
          json.(p, :original_url)
          json.(p, :make)
          json.(p, :model)
          json.(p, :exposure)
          json.(p, :f_number)
          json.(p, :iso)
          json.(p, :focal_length)
          json.(p, :film_make)
          json.(p, :film_type)
          json.(p, :latitude)
          json.(p, :longitude)
          json.(p, :width)
          json.(p, :height)
          json.(p, :crop)
          json.(p, :taken_at)
          json.(p, :updated_at)
          json.(p, :created_at)
        end
      end
    end
  end
end
