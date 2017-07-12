json.cache! "entry/json/#{entry.id}/#{entry.updated_at.to_i}" do
  json.type 'entry'
  json.id entry.id.to_s
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
          json.id p.id.to_s
          json.attributes do
            json.(p, :caption)
            json.(p, :formatted_caption)
            json.(p, :plain_caption)
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
            json.(p, :focal_x)
            json.(p, :focal_y)
            json.(p, :taken_at)
            json.(p, :updated_at)
            json.(p, :created_at)
          end
          json.links do
            entry_photo_widths(p, 'entry').each do |w|
              json.set! "width_#{w}", p.url(w: w)
            end
            entry_photo_widths(p, 'entry_list_item').each do |w|
              json.set! "square_#{w}", p.url(w: w, square: true)
            end
          end
        end
      end
    end
    json.tags do
      json.data do
        json.array! entry.combined_tags do |t|
          json.type 'tag'
          json.id t.id.to_s
          json.attributes do
            json.(t, :name)
            json.(t, :slug)
            json.(t, :taggings_count)
          end
          json.links do
            json.self tag_url(t.slug, page: nil)
          end
        end
      end
    end
    json.user do
      json.data do
        json.type 'user'
        json.id entry.user.id.to_s
        json.attributes do
          json.name entry.user.name
        end
      end
    end
    json.blog do
      json.data do
        json.type 'blog'
        json.id entry.blog.id.to_s
        json.attributes do
          json.name entry.blog.name
          json.description entry.blog.description
        end
      end
    end
  end
end
