class RemoveSmartCropFromPhotos < ActiveRecord::Migration[4.2]
  def self.up
    remove_column :photos, :use_smart_cropping
  end

  def self.down
    add_column :photos, :use_smart_cropping, :boolean
  end
end
