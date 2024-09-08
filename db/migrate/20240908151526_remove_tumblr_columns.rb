class RemoveTumblrColumns < ActiveRecord::Migration[7.0]
  def change
    remove_column :entries, :tumblr_id, :string
    remove_column :entries, :tumblr_reblog_key, :string
    remove_column :entries, :post_to_tumblr, :boolean
    remove_column :entries, :tumblr_text, :text
    remove_column :blogs, :tumblr, :string
    remove_column :profiles, :tumblr, :string
    remove_column :tag_customizations, :tumblr_tags, :text
  end
end
