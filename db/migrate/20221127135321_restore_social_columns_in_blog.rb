class RestoreSocialColumnsInBlog < ActiveRecord::Migration[7.0]
  def down
    remove_column :blogs, :email
    remove_column :blogs, :flickr
    remove_column :blogs, :instagram
    remove_column :blogs, :tumblr
  end

  def up
    add_column :blogs, :email, :string
    add_column :blogs, :flickr, :string
    add_column :blogs, :instagram, :string
    add_column :blogs, :tumblr, :string
  end
end
