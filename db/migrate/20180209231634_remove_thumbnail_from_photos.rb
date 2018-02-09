class RemoveThumbnailFromPhotos < ActiveRecord::Migration[5.1]
  def up
    remove_column :photos, :thumbnail
  end

  def down
    add_column :photos, :thumbnail, :text
  end
end
