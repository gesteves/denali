module Types
  class TagType < Types::BaseObject
    field :name, String, null: false, description: "The name of the tag"
    field :slug, String, null: false, description: "The URL slug for the tag"
  end
end
