class AddBlueskyAndMastodonHashtagsToTagCustomizations < ActiveRecord::Migration[8.0]
  def change
    add_column :tag_customizations, :bluesky_hashtags, :text
    add_column :tag_customizations, :mastodon_hashtags, :text
  end
end
