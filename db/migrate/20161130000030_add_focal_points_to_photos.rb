class AddFocalPointsToPhotos < ActiveRecord::Migration[5.0]
  def change
    add_column :photos, :focal_x, :float
    add_column :photos, :focal_y, :float
  end
end
