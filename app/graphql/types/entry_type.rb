module Types
  class EntryType < Types::BaseObject
    field :id, ID, null: false
    field :blog, Types::BlogType, null: false, description: "The blog this entry belongs to"
    field :body, String, null: true, description: "The body of the entry, as entered by the author, in Markdown"
    field :facebook_caption, String, null: true, description: "A Facebook-friendly caption for this entry"
    field :formatted_body, String, null: true, description: "The body of the entry, formatted in HTML"
    field :glass_caption, String, null: true, description: "A Glass-friendly caption for this entry"
    field :instagram_caption, String, null: true, description: "A Instagram-friendly caption for this entry"
    field :instagram_hashtags, String, null: true, description: "List of Instagram hashtags this entry can be tagged with"
    field :modified_at, String, null: false, description: "Date & time the entry was last publicly modified"
    field :photos_count, Integer, null: false, description: "Number of photos in this entry"
    field :plain_body, String, null: true, description: "The body of the entry, in plain text"
    field :plain_title, String, null: false, description: "The title of the entry, in plain text"
    field :preview_hash, String, null: false, description: "A unique identifier for unpublished entries"
    field :published_at, String, null: true, description: "Date & time the entry was published at"
    field :reddit_caption, String, null: true, description: "A reddit-friendly caption for this entry"
    field :short_url, String, null: true, method: :short_permalink_url, description: "Shorter version of the permalink URL for the entry"
    field :slug, String, null: false, description: "The slug at the end of the entry's URL"
    field :status, String, null: false, description: "The publish status of the entry"
    field :title, String, null: false, description: "The title of the entry, as entered by the author"
    field :twitter_caption, String, null: true, description: "A Twitter-friendly caption for this entry"
    field :url, String, null: false, method: :permalink_url, description: "Permalink URL for the entry"
    field :user, Types::UserType, null: false, description: "The author of this entry"
    field :tags, [Types::TagType], null: true, description: "The list of tags this entry is tagged with"
    field :photos, [Types::PhotoType], null: true, description: "The list of photos in this entry"
    field :related, [Types::EntryType], null: true, description: "A list of additional entries related to the entry"
    field :blog, Types::BlogType, null: false, description: "The blog this entry was published in"

    def tags
      object.combined_tags
    end
  end
end
