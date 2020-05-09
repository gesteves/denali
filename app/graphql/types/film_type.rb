module Types
  class FilmType < Types::BaseObject
    field :id, ID, null: false
    field :slug, String, null: true, description: "The slug of the film"
    field :make, String, null: true, description: "The brand of the film"
    field :model, String, null: true, description: "The type of film"
    field :name, String, null: true, method: :display_name, description: "The full name of the film (brand + type)"
  end
end
