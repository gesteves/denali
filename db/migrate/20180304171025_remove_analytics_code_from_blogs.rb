class RemoveAnalyticsCodeFromBlogs < ActiveRecord::Migration[5.1]
  def up
    remove_column :blogs, :analytics_code
  end

  def down
    add_column :blogs, :analytics_code, :text
  end
end
