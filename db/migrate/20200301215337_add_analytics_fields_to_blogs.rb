class AddAnalyticsFieldsToBlogs < ActiveRecord::Migration[5.2]
  def change
    add_column :blogs, :analytics_head, :text
    add_column :blogs, :analytics_body, :text
  end
end
