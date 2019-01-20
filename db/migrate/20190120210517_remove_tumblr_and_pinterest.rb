class RemoveTumblrAndPinterest < ActiveRecord::Migration[5.2]
  def up
    remove_column :blogs, :tumblr
    remove_column :entries, :post_to_tumblr
    remove_column :entries, :post_to_pinterest
    remove_column :entries, :tumblr_id
  end

  def down
    add_column :blogs, :tumblr, :string
    add_column :entries, :post_to_tumblr, :boolean
    add_column :entries, :post_to_pinterest, :boolean
    add_column :entries, :tumblr_id, :string
    add_index :entries, :tumblr_id
  end
end
