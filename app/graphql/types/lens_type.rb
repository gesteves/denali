module Types
  class LensType < Types::BaseObject
    field :id, ID, null: false
    field :slug, String, null: true, description: "The slug of the lens"
    field :make, String, null: true, description: "The brand of the lens"
    field :model, String, null: true, description: "The model of the lens"
    field :name, String, null: true, method: :display_name, description: "The full name of the lens (brand + model)"
  end
end
