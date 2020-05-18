class RemoveColorColumnsFromPhotos < ActiveRecord::Migration[5.2]
  def up
    remove_column :photos, :color_vibrant
    remove_column :photos, :color_muted
  end

  def down
    add_column :photos, :color_vibrant, :string
    add_column :photos, :color_muted, :string
  end
end
