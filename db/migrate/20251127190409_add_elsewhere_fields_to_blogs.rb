class AddElsewhereFieldsToBlogs < ActiveRecord::Migration[8.0]
  def change
    add_column :blogs, :elsewhere_heading, :string
    add_column :blogs, :elsewhere_cta, :string
  end
end
