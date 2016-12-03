class AddExifToPhotos < ActiveRecord::Migration[4.2]
  def change
    add_column :photos, :make, :string
    add_column :photos, :model, :string
    add_column :photos, :taken_at, :datetime
    add_column :photos, :exposure, :string
    add_column :photos, :f_number, :float
    add_column :photos, :latitude, :float
    add_column :photos, :longitude, :float
    add_column :photos, :width, :integer
    add_column :photos, :height, :integer
    add_column :photos, :iso, :integer
    add_column :photos, :focal_length, :integer
  end
end
