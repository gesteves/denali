class AddTumblrAgain < ActiveRecord::Migration[5.2]
  def up
    add_column :blogs, :tumblr, :string
    add_column :entries, :post_to_tumblr, :boolean, default: true
  end

  def down
    remove_column :blogs, :tumblr
    remove_column :entries, :post_to_tumblr
  end
end
