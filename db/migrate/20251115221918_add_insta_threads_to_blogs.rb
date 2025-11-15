class AddInstaThreadsToBlogs < ActiveRecord::Migration[8.0]
  def change
    add_column :blogs, :instagram, :string
    add_column :blogs, :threads, :string
  end
end
