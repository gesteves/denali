module Types
  class FilmType < Types::BaseObject
    field :id, ID, null: false
    field :make, String, null: true
    field :model, String, null: true
    field :name, String, null: true, method: :display_name
  end
end
