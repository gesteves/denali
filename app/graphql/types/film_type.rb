module Types
  class FilmType < Types::BaseObject
    field :id, ID, null: false
    field :make, String, null: true
    field :model, String, null: true
    field :display_name, String, null: true
  end
end
