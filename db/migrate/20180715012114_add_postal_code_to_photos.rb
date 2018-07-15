class AddPostalCodeToPhotos < ActiveRecord::Migration[5.2]
  def change
    add_column :photos, :postal_code, :string
  end
end
