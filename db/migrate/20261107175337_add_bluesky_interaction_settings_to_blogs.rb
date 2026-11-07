class AddBlueskyInteractionSettingsToBlogs < ActiveRecord::Migration[8.1]
  def change
    add_column :blogs, :bluesky_reply_audience, :string, null: false, default: 'everyone'
    add_column :blogs, :bluesky_allow_quotes, :boolean, null: false, default: true
  end
end
