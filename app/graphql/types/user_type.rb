module Types
  class UserType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: true
    field :first_name, String, null: true
    field :last_name, String, null: true
    field :avatar_url, String, null: true
  end
end
