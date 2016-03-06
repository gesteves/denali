class AddDominantColorToPhoto < ActiveRecord::Migration
  def change
    add_column :photos, :dominant_color, :string
  end
end
