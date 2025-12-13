class AddPushNotificationsTextToBlogs < ActiveRecord::Migration[8.0]
  def change
    add_column :blogs, :push_notifications_heading, :string
    add_column :blogs, :push_notifications_cta, :string
  end
end
