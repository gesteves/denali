module Types
  class UserType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: true, description: "The full name of the user"
    field :first_name, String, null: true, description: "The first name of the user"
    field :last_name, String, null: true, description: "The last name of the user"
  end
end
