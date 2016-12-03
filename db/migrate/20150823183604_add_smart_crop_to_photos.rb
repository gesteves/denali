class AddSmartCropToPhotos < ActiveRecord::Migration[4.2]
  def change
    add_column :photos, :use_smart_cropping, :boolean
  end
end
