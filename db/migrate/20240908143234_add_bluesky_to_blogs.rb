class AddBlueskyToBlogs < ActiveRecord::Migration[7.0]
  def change
    add_column :blogs, :bluesky, :string
  end
end
