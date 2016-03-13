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
          if entry.show_in_map
            json.(p, :latitude)
            json.(p, :longitude)
          end
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
  json.tags do
    json.data do
      json.array! entry.tags do |t|
        json.type 'tag'
        json.(t, :id)
        json.attributes do
          json.(t, :name)
          json.(t, :slug)
          json.(t, :taggings_count)
        end
        json.links do
          json.self tag_url(t.slug)
        end
      end
    end
  end
  json.user do
    json.data do
      json.type 'user'
      json.id entry.user.id
      json.attributes do
        json.name entry.user.name
      end
    end
  end
  json.blog do
    json.data do
      json.type 'blog'
      json.id entry.blog.id
      json.attributes do
        json.name entry.blog.name
        json.description entry.blog.description
      end
    end
  end
end
