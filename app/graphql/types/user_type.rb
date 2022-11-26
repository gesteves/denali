module Types
  class UserType < Types::BaseObject
    field :id, ID, null: false
    field :profile, Types::ProfileType, null: false, description: "The profile for this user"
  end
end
