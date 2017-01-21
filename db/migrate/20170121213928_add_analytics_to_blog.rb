class AddAnalyticsToBlog < ActiveRecord::Migration[5.0]
  def change
    add_column :blogs, :analytics_code, :text
  end
end
