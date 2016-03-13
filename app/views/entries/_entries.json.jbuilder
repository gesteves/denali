json.data do
  json.array! entries do |e|
    json.cache! "entry/json/#{e.id}/#{e.updated_at.to_i}" do
      json.type 'entry'
      json.(e, :id)
      json.attributes do
        json.(e, :title)
        json.(e, :plain_title)
        json.(e, :body)
        json.(e, :formatted_body)
        json.(e, :plain_body)
        json.(e, :slug)
        json.(e, :photos_count)
        json.(e, :published_at)
        json.(e, :updated_at)
        json.(e, :created_at)
      end
      json.relationships do
        json.photos do
          json.data do
            json.array! e.photos do |p|
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
      json.links do
        json.self e.permalink_url
        json.prev e.older.permalink_url if e.older.present?
        json.next e.newer.permalink_url if e.newer.present?
      end
    end
  end
end
