class AddPublishScheduleCountToBlog < ActiveRecord::Migration[5.2]
  def change
    add_column :blogs, :publish_schedules_count, :integer
  end
end
