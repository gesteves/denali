class RemovePaperclipColumns < ActiveRecord::Migration[5.2]
  def up
    remove_column :photos, :image_file_name
    remove_column :photos, :image_content_type
    remove_column :photos, :image_file_size
    remove_column :photos, :image_updated_at
    remove_column :photos, :paperclip_image_url

    remove_column :blogs, :favicon_file_name
    remove_column :blogs, :favicon_content_type
    remove_column :blogs, :favicon_file_size
    remove_column :blogs, :favicon_updated_at
    remove_column :blogs, :paperclip_favicon_url

    remove_column :blogs, :touch_icon_file_name
    remove_column :blogs, :touch_icon_content_type
    remove_column :blogs, :touch_icon_file_size
    remove_column :blogs, :touch_icon_updated_at
    remove_column :blogs, :paperclip_touch_icon_url

    remove_column :blogs, :logo_file_name
    remove_column :blogs, :logo_content_type
    remove_column :blogs, :logo_file_size
    remove_column :blogs, :logo_updated_at
    remove_column :blogs, :paperclip_logo_url
  end

  def down
    add_column :photos, :image_file_name, :string
    add_column :photos, :image_content_type, :string
    add_column :photos, :image_file_size, :integer
    add_column :photos, :image_updated_at, :datetime
    add_column :photos, :paperclip_image_url, :string

    add_column :blogs, :favicon_file_name, :string
    add_column :blogs, :favicon_content_type, :string
    add_column :blogs, :favicon_file_size, :integer
    add_column :blogs, :favicon_updated_at, :datetime
    add_column :blogs, :paperclip_favicon_url, :string

    add_column :blogs, :touch_icon_file_name, :string
    add_column :blogs, :touch_icon_content_type, :string
    add_column :blogs, :touch_icon_file_size, :integer
    add_column :blogs, :touch_icon_updated_at, :datetime
    add_column :blogs, :paperclip_touch_icon_url, :string

    add_column :blogs, :logo_file_name, :string
    add_column :blogs, :logo_content_type, :string
    add_column :blogs, :logo_file_size, :integer
    add_column :blogs, :logo_updated_at, :datetime
    add_column :blogs, :paperclip_logo_url, :string
  end
end
