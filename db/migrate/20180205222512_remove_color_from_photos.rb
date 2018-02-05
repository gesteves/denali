class RemoveColorFromPhotos < ActiveRecord::Migration[5.1]
  def up
    remove_column :photos, :color
  end

  def down
    add_column :photos, :color, :boolean, default: false
  end
end
