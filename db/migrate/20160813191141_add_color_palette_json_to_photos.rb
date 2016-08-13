class AddColorPaletteJsonToPhotos < ActiveRecord::Migration[5.0]
  def change
    add_column :photos, :color_palette_json, :text
  end
end
