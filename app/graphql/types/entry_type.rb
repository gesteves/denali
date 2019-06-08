module Types
  class EntryType < Types::BaseObject
    field :id, ID, null: false
    field :title, String, null: false
    field :plain_title, String, null: false
    field :body, String, null: true
    field :formatted_body, String, null: true
    field :plain_body, String, null: true
    field :slug, String, null: false
    field :url, String, null: false, method: :permalink_url
    field :short_url, String, null: true, method: :short_permalink_url
    field :amp_url, String, null: true
    field :published_at, String, null: false
    field :photos_count, Integer, null: false
    field :instagram_hashtags, String, null: true
    field :instagram_caption, String, null: true
    field :blog, Types::BlogType, null: false
    field :user, Types::UserType, null: false
    field :tags, [Types::TagType], null: true
    field :photos, [Types::PhotoType], null: true
    field :related, [Types::EntryType], null: true
    def tags
      object.combined_tags
    end
  end
end
