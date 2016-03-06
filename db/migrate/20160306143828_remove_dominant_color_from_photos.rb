class RemoveDominantColorFromPhotos < ActiveRecord::Migration
  def self.up
    remove_column :photos, :dominant_color
  end

  def self.down
    add_column :photos, :dominant_color, :string
  end
end
