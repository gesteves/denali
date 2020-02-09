class AddMapStyleToBlogs < ActiveRecord::Migration[5.2]
  def change
    add_column :blogs, :map_style, :string
  end
end
