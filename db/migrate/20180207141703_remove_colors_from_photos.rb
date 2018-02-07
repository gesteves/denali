class RemoveColorsFromPhotos < ActiveRecord::Migration[5.1]
  def up
    remove_column :photos, :color_vibrant_dark
    remove_column :photos, :color_vibrant_light
    remove_column :photos, :color_muted_light
    remove_column :photos, :color_muted_dark
  end

  def down
    add_column :photos, :color_vibrant_dark, :string
    add_column :photos, :color_vibrant_light, :string
    add_column :photos, :color_muted_light, :string
    add_column :photos, :color_muted_dark, :string
  end
end
