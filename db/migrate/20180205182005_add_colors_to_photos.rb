class AddColorsToPhotos < ActiveRecord::Migration[5.1]
  def change
    add_column :photos, :color_vibrant, :string
    add_column :photos, :color_vibrant_dark, :string
    add_column :photos, :color_vibrant_light, :string
    add_column :photos, :color_muted, :string
    add_column :photos, :color_muted_light, :string
    add_column :photos, :color_muted_dark, :string
  end
end
