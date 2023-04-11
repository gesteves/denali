module Types
  class CropType < Types::BaseObject
    field :id, ID, null: false
    field :aspect_ratio, String, null: false, description: "The aspect ratio for this crop"
    field :x, Float, null: false, description: "The relative starting X coordinate of the crop area"
    field :y, Float, null: false, description: "The relative starting Y coordinate of the crop area"
    field :width, Float, null: false, description: "The relative width of the crop area"
    field :height, Float, null: false, description: "The relative height of the crop area"
    field :rect, [Integer], null: false, description: "An array with the left, top, right, bottom coordinates of the crop area"

    def rect
      object.to_rect
    end
  end
end
