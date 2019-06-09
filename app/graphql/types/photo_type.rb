module Types
  class PhotoType < Types::BaseObject
    MAX_WIDTH = 3360

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
    field :color_palette, [String], null: true
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
    field :urls, [String], null: false do
      argument :widths, [Integer], required: false, default_value: [1280], prepare: -> (widths, ctx) { widths.reject { |w| w > MAX_WIDTH } }
    end
    field :thumbnail_urls, [String], null: false do
      argument :widths, [Integer], required: false, default_value: [640], prepare: -> (widths, ctx) { widths.reject { |w| w > MAX_WIDTH } }
    end

    def urls(widths:)
      widths.map { |w| object.url(w: w) }
    end

    def thumbnail_urls(widths:)
      widths.map { |w| object.url(w: w, square: true) }
    end

    def color_palette
      object.color_palette.split(',')
    end
  end
end
