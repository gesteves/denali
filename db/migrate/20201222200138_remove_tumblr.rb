class RemoveTumblr < ActiveRecord::Migration[6.0]
  def up
    remove_column :blogs, :tumblr
    remove_column :entries, :post_to_tumblr
    remove_column :tag_customizations, :tumblr_tags
  end

  def down
    add_column :blogs, :tumblr, :string
    add_column :entries, :post_to_tumblr, :boolean
    add_column :tag_customizations, :tumblr_tags, :text
  end
end
