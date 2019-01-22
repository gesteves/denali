class AddMetaDescriptionToBlogs < ActiveRecord::Migration[5.2]
  def change
    add_column :blogs, :meta_description, :text
  end
end
