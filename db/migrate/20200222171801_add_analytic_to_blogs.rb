class AddAnalyticToBlogs < ActiveRecord::Migration[5.2]
  def change
    add_column :blogs, :analytics, :text
  end
end
