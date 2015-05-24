class RemoveFocalLengthEquivalentFromPhotos < ActiveRecord::Migration
  def change
    remove_column :photos, :focal_length_equivalent
  end
end
