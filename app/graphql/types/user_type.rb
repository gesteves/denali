module Types
  class UserType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: true, description: "Full name of the user"
    field :first_name, String, null: true, description: "First name of the user"
    field :last_name, String, null: true, description: "Last name of the user"
    field :avatar_url, String, null: true, description: "URL of the user's avatar"
  end
end
