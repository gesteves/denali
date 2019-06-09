module Types
  class LensType < Types::BaseObject
    field :id, ID, null: false
    field :make, String, null: true, description: "The brand of the lens"
    field :model, String, null: true, description: "The model of the les"
    field :name, String, null: true, method: :display_name, description: "The full name of the lens (brand + model)"
  end
end
