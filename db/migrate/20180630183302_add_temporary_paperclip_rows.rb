class AddTemporaryPaperclipRows < ActiveRecord::Migration[5.2]
  def change
    add_column :photos, :paperclip_image_url, :string
    add_column :blogs, :paperclip_favicon_url, :string
    add_column :blogs, :paperclip_touch_icon_url, :string
    add_column :blogs, :paperclip_logo_url, :string
  end
end
