module Types
  class PhotoType < Types::BaseObject
    MAX_WIDTH = 3360

    field :id, ID, null: false
    field :alt_text, String, null: true, description: "Text description of the image"
    field :aperture, Float, null: true, method: :f_number, description: "f/number the photo was made at"
    field :black_and_white, Boolean, null: true, method: :black_and_white?, description: "Whether or not the photo is in black & white"
    field :blurhash, String, null: true, description: "A compact representation of the placeholder for this photo"
    field :blurhash_data_uri, String, null: true, description: "A base64 data URI of the placeholder for this photo"
    field :camera, Types::CameraType, null: true, description: "The camera used to take the photo"
    field :color, Boolean, null: true, method: :color?, description: "Whether or not the photo is in color"
    field :download_url, String, null: true, description: "The URL to download the full size version of the image"
    field :exposure, String, null: true, description: "Exposure time of the photo"
    field :facebook_card_url, String, null: false, description: "URL of a version of the photo optimized for Facebook OpenGraph"
    field :filename, String, null: false, description: "The file name of the original uploaded image"
    field :film, Types::FilmType, null: true, description: "The film used to take the photo"
    field :flickr_caption, String, null: true, description: "A full Flickr-friendly caption for this photo"
    field :focal_length, Integer, null: true, description: "Focal length the photo was made at"
    field :focal_length_with_unit, String, null: true, description: "Focal length the photo was made at, formatted"
    field :focal_x, Float, null: true, description: "X coordinate of the focal point of the photo, as float between 0 and 1"
    field :focal_y, Float, null: true, description: "Y coordinate of the focal point of the photo, as float between 0 and 1"
    field :formatted_aperture, String, null: true, description: "f/number the photo was made at, formatted"
    field :formatted_exposure, String, null: true, method: :formatted_exposure, description: "Exposure time of the photo, formatted"
    field :height, Integer, null: false, description: "Height of the original image"
    field :horizontal, Boolean, null: false, method: :is_horizontal?, description: "Whether or not the photo is in landscape orientation"
    field :instagram_url, String, null: false, description: "URL of a version of the photo optimized for the Instagram feed"
    field :iphone_wallpaper_url, String, null: false, description: "URL of a version of the photo optimized for an iPhone wallpaper"
    field :plain_metadata, String, null: true, description: "Metadata for the photo, in plain text"
    field :reddit_caption, String, null: true, description: "A reddit-friendly caption for this photo"
    field :iso, Integer, null: true, description: "ISO the photo was made at"
    field :latitude, Float, null: true, description: "Latitude the photo was made at"
    field :longitude, Float, null: true, description: "Longitude the photo was made at"
    field :location, String, null: true, description: "The location this photo was made in"
    field :territories, [String], null: true, description: "The native lands this photo was made in"
    field :lens, Types::LensType, null: true, description: "The lens used to make the photo"
    field :square, Boolean, null: false, method: :is_square?, description: "Whether or not the photo is square"
    field :vertical, Boolean, null: false, method: :is_vertical?, description: "Whether or not the photo is in portrait orientation"
    field :width, Integer, null: false, description: "Width of the original image"
    field :crops, [Types::CropType], null: true, description: "The crops available for this photo"
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
    field :instagram_story_url, String, null: false, description: "URL of a version of the photo optimized for Instagram Stories" do
      argument :crop, Boolean, required: false, default_value: false
    end

    def urls(widths:)
      widths.map { |w| object.url(width: w) }
    end

    def thumbnail_urls(widths:)
      widths.map { |w| object.url(width: w, aspect_ratio: '1:1') }
    end

    def crop_url(width:, height:)
      object.url(width: width, height: height)
    end

    def latitude
      object.latitude if object.entry.show_location? && context[:is_authorized]
    end

    def longitude
      object.longitude if object.entry.show_location? && context[:is_authorized]
    end

    def location
      object.formatted_location
    end

    def filename
      object.image.filename.to_s
    end

    def territories
      return [] if object.territories.nil?
      JSON.parse(object.territories)
    end

    def download_url
      object.image.url(disposition: :attachment) if context[:is_authorized]
    end

    def instagram_story_url(crop:)
      object.instagram_story_url(crop: crop)
    end
  end
end
