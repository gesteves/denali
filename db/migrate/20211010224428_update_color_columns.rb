class UpdateColorColumns < ActiveRecord::Migration[6.1]
  def up
    add_column :photos, :color, :boolean
    add_column :photos, :black_and_white, :boolean
    add_column :photos, :dominant_color, :string
    remove_column :photos, :color_palette
  end

  def down
    remove_column :photos, :color
    remove_column :photos, :black_and_white
    remove_column :photos, :dominant_color
    add_column :photos, :color_palette, :string
  end
end
