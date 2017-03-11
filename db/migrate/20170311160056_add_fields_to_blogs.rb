class AddFieldsToBlogs < ActiveRecord::Migration[5.0]
  def change
    add_column :blogs, :instagram, :string
    add_column :blogs, :twitter, :string
    add_column :blogs, :tumblr, :string
    add_column :blogs, :email, :string
    add_column :blogs, :header_logo_svg, :text
    add_column :blogs, :additional_meta_tags, :text
  end
end
