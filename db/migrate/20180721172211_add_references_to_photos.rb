class AddReferencesToPhotos < ActiveRecord::Migration[5.2]
  def change
    add_reference :photos, :camera, foreign_key: true
    add_reference :photos, :lens, foreign_key: true
    add_reference :photos, :film, foreign_key: true
  end
end
