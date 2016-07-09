class AddFilmToPhotos < ActiveRecord::Migration[4.2]
  def change
    add_column :photos, :film_make, :string
    add_column :photos, :film_type, :string
  end
end
