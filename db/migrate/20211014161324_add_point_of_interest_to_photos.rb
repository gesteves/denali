class AddPointOfInterestToPhotos < ActiveRecord::Migration[6.1]
  def change
    add_column :photos, :point_of_interest, :string
  end
end
