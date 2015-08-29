class AddCropToPhotos < ActiveRecord::Migration
  def change
    add_column :photos, :crop, :string
  end
end
