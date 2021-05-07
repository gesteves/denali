class AddBlurhashToPhotos < ActiveRecord::Migration[6.1]
  def change
    add_column :photos, :blurhash, :string
  end
end
