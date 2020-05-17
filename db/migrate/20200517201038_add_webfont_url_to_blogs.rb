class AddWebfontUrlToBlogs < ActiveRecord::Migration[5.2]
  def change
    add_column :blogs, :webfonts_url, :string
  end
end
