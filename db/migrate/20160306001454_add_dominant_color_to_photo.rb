class AddDominantColorToPhoto < ActiveRecord::Migration[4.2]
  def change
    add_column :photos, :dominant_color, :string
  end
end
