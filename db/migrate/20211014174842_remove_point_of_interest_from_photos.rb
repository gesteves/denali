class RemovePointOfInterestFromPhotos < ActiveRecord::Migration[6.1]
  def up
    remove_column :photos, :point_of_interest
  end

  def down
    add_column :photos, :point_of_interest, :string
  end
end
