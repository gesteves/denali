class AddThumbnailToPhotos < ActiveRecord::Migration[5.1]
  def change
    add_column :photos, :thumbnail, :text
  end
end
