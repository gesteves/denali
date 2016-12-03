class RemoveCropFromPhotos < ActiveRecord::Migration[5.0]
  def self.up
    remove_column :photos, :crop
  end

  def self.down
    add_column :photos, :crop, :string
  end
end
