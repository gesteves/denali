module Types
  class PhotoType < Types::BaseObject
    MAX_WIDTH = 3360

    field :id, ID, null: false
    field :alt_text, String, null: true, description: "Text description of the image"
    field :exposure, String, null: true, method: :formatted_exposure, description: "Exposure time of the photo"
    field :aperture, String, null: true, method: :formatted_aperture, description: "f/number the photo was taken at"
    field :width, Integer, null: false, description: "Width of the original image"
    field :height, Integer, null: false, description: "Height of the original image"
    field :iso, Integer, null: true, description: "ISO the photo was taken at"
    field :focal_length, String, null: true, method: :focal_length_with_unit, description: "Focal length the photo was taken at"
    field :focal_x, Float, null: true, description: "X coordinate of the focal point of the photo, as float between 0 and 1"
    field :focal_y, Float, null: true, description: "Y coordinate of the focal point of the photo, as float between 0 and 1"
    field :color_vibrant, String, null: true, description: "Hex representation of the photo's most prominent vibrant color"
    field :color_muted, String, null: true, description: "Hex representation of the photo's most prominent muted color"
    field :color_palette, [String], null: true, description: "List of hex values of the 6 most prominent colors in the photo"
    field :camera, Types::CameraType, null: true, description: "The camera used to take the photo"
    field :lens, Types::LensType, null: true, description: "The lens used to take the photo"
    field :film, Types::FilmType, null: true, description: "The film used to take the photo"
    field :instagram_url, String, null: false, description: "URL of a version of the photo optimized for the Instagram feed"
    field :instagram_story_url, String, null: false, description: "URL of a version of the photo optimized for Instagram Stories"
    field :square, Boolean, null: false, method: :is_square?, description: "Whether or not the photo is square"
    field :horizontal, Boolean, null: false, method: :is_horizontal?, description: "Whether or not the photo is in landscape orientation"
    field :vertical, Boolean, null: false, method: :is_vertical?, description: "Whether or not the photo is in portrait orientation"
    field :color, Boolean, null: true, method: :color?, description: "Whether or not the photo is in color"
    field :black_and_white, Boolean, null: true, method: :black_and_white?, description: "Whether or not the photo is in black & white"
    field :prominent_color, String, null: true, description: "Hex representation of the photo's most prominent color"
    field :urls, [String], null: false, description: "List of URLs for the photo in different widths" do
      argument :widths, [Integer], required: false, default_value: [1280], prepare: -> (widths, ctx) { widths.reject { |w| w > MAX_WIDTH } }
    end
    field :thumbnail_urls, [String], null: false, description: "List of URLs for the photo's square thumbnail in different widths" do
      argument :widths, [Integer], required: false, default_value: [640], prepare: -> (widths, ctx) { widths.reject { |w| w > MAX_WIDTH } }
    end
    field :crop_url, String, null: false, description: "URL for the photo, cropped at the given width and height" do
      argument :width, Integer, required: true, prepare: -> (width, ctx) { [MAX_WIDTH, width].min }
      argument :height, Integer, required: true, prepare: -> (height, ctx) { [MAX_WIDTH, height].min }
    end

    def urls(widths:)
      widths.map { |w| object.url(w: w) }
    end

    def thumbnail_urls(widths:)
      widths.map { |w| object.url(w: w, square: true) }
    end

    def crop_url(width:, height:)
      object.url(w: width, h: height)
    end

    def color_palette
      object.color_palette.split(',')
    end
  end
end
