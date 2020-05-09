module Types
  class CameraType < Types::BaseObject
    field :id, ID, null: false
    field :slug, String, null: true, description: "The slug of the camera"
    field :make, String, null: true, description: "The brand of the camera"
    field :model, String, null: true, description: "The model of the camera"
    field :name, String, null: true, method: :display_name, description: "The full name of the camera (brand + model)"
  end
end
