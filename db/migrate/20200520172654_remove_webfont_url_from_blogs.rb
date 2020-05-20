class RemoveWebfontUrlFromBlogs < ActiveRecord::Migration[5.2]
  def up
    remove_column :blogs, :webfonts_url
  end

  def down
    add_column :blogs, :webfonts_url, :string
  end
end
