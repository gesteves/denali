class AddTumblrToBlogs < ActiveRecord::Migration[7.0]
  def change
    add_column :blogs, :tumblr, :string
  end
end
