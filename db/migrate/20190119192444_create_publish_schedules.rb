class CreatePublishSchedules < ActiveRecord::Migration[5.2]
  def change
    create_table :publish_schedules do |t|
      t.integer :weekday
      t.integer :hour
      t.references :blog
      t.timestamps
    end
  end
end
