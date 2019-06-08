module Types
  class PhotoType < Types::BaseObject
    field :id, ID, null: false
    field :alt_text, String, null: true
    field :exposure, String, null: true, method: :formatted_exposure
    field :aperture, String, null: true, method: :formatted_aperture
    field :width, Integer, null: false
    field :height, Integer, null: false
    field :iso, Integer, null: true
    field :focal_length, String, null: true, method: :focal_length_with_unit
    field :focal_x, Float, null: true
    field :focal_y, Float, null: true
    field :color_vibrant, String, null: true
    field :color_muted, String, null: true
    field :color_palette, String, null: true
    field :postal_code, String, null: true
    field :camera, Types::CameraType, null: true
    field :lens, Types::LensType, null: true
    field :film, Types::FilmType, null: true
    field :instagram_url, String, null: false
    field :instagram_story_url, String, null: false
    field :square, Boolean, null: false, method: :is_square?
    field :horizontal, Boolean, null: false, method: :is_horizontal?
    field :vertical, Boolean, null: false, method: :is_vertical?
    field :color, Boolean, null: false, method: :color?
    field :black_and_white, Boolean, null: false, method: :black_and_white?
    field :prominent_color, String, null: true
    field :url, String, null: false do
      argument :width, Integer, required: true, prepare: -> (width, ctx) { [width, 3360].min }
    end
    field :thumbnail_url, String, null: false do
      argument :width, Integer, required: true, prepare: -> (width, ctx) { [width, 3360].min }
    end
    field :urls, [String], null: false do
      argument :widths, [Integer], required: true, prepare: -> (widths, ctx) { widths.reject { |w| w > 3360 } }
    end
    field :thumbnail_urls, [String], null: false do
      argument :widths, [Integer], required: true, prepare: -> (widths, ctx) { widths.reject { |w| w > 3360 } }
    end

    def urls(widths:)
      widths.map { |w| object.url(w: w) }
    end

    def url(width:)
      object.url(w: width)
    end

    def thumbnail_url(width:)
      object.url(w: width, square: true)
    end

    def thumbnail_urls(widths:)
      widths.map { |w| object.url(w: w, square: true) }
    end
  end
end
