class RemoveSmartCropFromPhotos < ActiveRecord::Migration
  def self.up
    remove_column :photos, :use_smart_cropping
  end

  def self.down
    add_column :photos, :use_smart_cropping, :boolean
  end
end
