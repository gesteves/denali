class AddFilmToPhotos < ActiveRecord::Migration
  def change
    add_column :photos, :film_make, :string
    add_column :photos, :film_type, :string
  end
end
