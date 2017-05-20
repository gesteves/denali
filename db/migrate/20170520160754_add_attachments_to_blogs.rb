class AddAttachmentsToBlogs < ActiveRecord::Migration[5.0]
  def up
    add_attachment :blogs, :favicon
    add_attachment :blogs, :touch_icon
  end

  def down
    remove_attachment :blogs, :favicon
    remove_attachment :blogs, :touch_icon
  end
end
