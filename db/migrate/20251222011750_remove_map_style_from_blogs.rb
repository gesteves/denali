class RemoveMapStyleFromBlogs < ActiveRecord::Migration[8.0]
  def change
    remove_column :blogs, :map_style, :string
  end
end
