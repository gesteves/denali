class AddPaletteToPhotos < ActiveRecord::Migration[5.1]
  def change
    add_column :photos, :color_palette, :string
  end
end
