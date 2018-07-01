class AddAttachmentsToBlogs < ActiveRecord::Migration[5.0]
  def change
    add_column :blogs, :favicon_file_name, :string
    add_column :blogs, :favicon_content_type, :string
    add_column :blogs, :favicon_file_size, :integer
    add_column :blogs, :favicon_updated_at, :datetime

    add_column :blogs, :touch_icon_file_name, :string
    add_column :blogs, :touch_icon_content_type, :string
    add_column :blogs, :touch_icon_file_size, :integer
    add_column :blogs, :touch_icon_updated_at, :datetime
  end
end
