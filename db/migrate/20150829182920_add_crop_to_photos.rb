class AddCropToPhotos < ActiveRecord::Migration[4.2]
  def change
    add_column :photos, :crop, :string
  end
end
