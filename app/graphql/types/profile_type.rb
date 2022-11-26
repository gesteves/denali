module Types
  class ProfileType < Types::BaseObject
    field :id, ID, null: false
    field :username, String, null: false, description: "The user's username"
    field :name, String, null: true, description: "The user's display name"
    field :bio, String, null: true, description: "A full bio, as entered by the author in Markdown"
    field :summary, String, null: true, description: "A shorter bio, as entered by the author in plain text"
    field :user, Types::UserType, null: false, description: "The user of this profile"
    field :email, String, null: true, description: "Contact email for the user"
    field :flickr, String, null: true, description: "Flickr account for the user"
    field :instagram, String, null: true, description: "Instagram account for the user"
    field :tumblr, String, null: true, description: "Tumblr account for the user"
    field :tumblr_username, String, null: true, description: "Tumblr username for the user"
  end
end
