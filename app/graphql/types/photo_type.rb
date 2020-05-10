module Types
  class PhotoType < Types::BaseObject
    MAX_WIDTH = 3360

    field :id, ID, null: false
    field :alt_text, String, null: true, description: "Text description of the image"
    field :aperture, Float, null: true, method: :f_number, description: "f/number the photo was made at"
    field :black_and_white, Boolean, null: true, method: :black_and_white?, description: "Whether or not the photo is in black & white"
    field :camera, Types::CameraType, null: true, description: "The camera used to take the photo"
    field :color_muted, String, null: true, description: "Hex representation of the photo's most prominent muted color"
    field :color_palette, [String], null: true, description: "List of hex values of the 6 most prominent colors in the photo"
    field :color_vibrant, String, null: true, description: "Hex representation of the photo's most prominent vibrant color"
    field :color, Boolean, null: true, method: :color?, description: "Whether or not the photo is in color"
    field :exposure, String, null: true, description: "Exposure time of the photo"
    field :filename, String, null: false, description: "The file name of the original uploaded image"
    field :film, Types::FilmType, null: true, description: "The film used to take the photo"
    field :focal_length, Integer, null: true, description: "Focal length the photo was made at"
    field :focal_length_with_unit, String, null: true, description: "Focal length the photo was made at, formatted"
    field :focal_x, Float, null: true, description: "X coordinate of the focal point of the photo, as float between 0 and 1"
    field :focal_y, Float, null: true, description: "Y coordinate of the focal point of the photo, as float between 0 and 1"
    field :formatted_aperture, String, null: true, description: "f/number the photo was made at, formatted"
    field :formatted_exposure, String, null: true, method: :formatted_exposure, description: "Exposure time of the photo, formatted"
    field :height, Integer, null: false, description: "Height of the original image"
    field :horizontal, Boolean, null: false, method: :is_horizontal?, description: "Whether or not the photo is in landscape orientation"
    field :instagram_story_url, String, null: false, description: "URL of a version of the photo optimized for Instagram Stories"
    field :instagram_url, String, null: false, description: "URL of a version of the photo optimized for the Instagram feed"
    field :iso, Integer, null: true, description: "ISO the photo was made at"
    field :latitude, Float, null: true, description: "Latitude the photo was made at"
    field :longitude, Float, null: true, description: "Longitude the photo was made at"
    field :lens, Types::LensType, null: true, description: "The lens used to make the photo"
    field :prominent_color, String, null: true, description: "Hex representation of the photo's most prominent color"
    field :square, Boolean, null: false, method: :is_square?, description: "Whether or not the photo is square"
    field :vertical, Boolean, null: false, method: :is_vertical?, description: "Whether or not the photo is in portrait orientation"
    field :width, Integer, null: false, description: "Width of the original image"
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

    def latitude
      object.latitude if object.entry.show_in_map?
    end

    def longitude
      object.longitude if object.entry.show_in_map?
    end

    def filename
      object.image.filename.to_s
    end
  end
end
