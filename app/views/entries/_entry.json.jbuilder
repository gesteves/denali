json.cache! entry do
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
            json.(p, :keywords)
            json.(p, :exposure)
            json.(p, :f_number)
            json.(p, :iso)
            json.(p, :focal_length)
            json.camera p.camera.display_name if p.camera.present?
            json.lens p.lens.display_name if p.lens.present? && !p.camera&.is_phone?
            json.film p.film.display_name if p.film.present?
            if entry.show_in_map && p.has_location?
              json.(p, :latitude)
              json.(p, :longitude)
              json.(p, :neighborhood)
              json.(p, :locality)
              json.(p, :sublocality)
              json.(p, :administrative_area)
              json.(p, :postal_code)
              json.(p, :country)
            end
            json.(p, :width)
            json.(p, :height)
            json.(p, :focal_x)
            json.(p, :focal_y)
            json.(p, :taken_at)
            json.(p, :color_palette)
            json.(p, :color_vibrant)
            json.(p, :color_muted)
            json.(p, :color?)
            json.(p, :black_and_white?)
            json.(p, :updated_at)
            json.(p, :created_at)
          end
          json.links do
            entry_photo_widths(p, 'entry_list').each do |w|
              json.set! "width_#{w}", p.url(w: w)
            end
            entry_photo_widths(p, 'entry_list_square').each do |w|
              json.set! "square_#{w}", p.url(w: w, square: true)
            end
          end
        end
      end
    end
  end
end
