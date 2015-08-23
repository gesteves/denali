class AddSmartCropToPhotos < ActiveRecord::Migration
  def change
    add_column :photos, :use_smart_cropping, :boolean
  end
end
