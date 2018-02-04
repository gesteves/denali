class AddAddressFieldsToPhotos < ActiveRecord::Migration[5.1]
  def change
    add_column :photos, :country, :string
    add_column :photos, :locality, :string
    add_column :photos, :sublocality, :string
    add_column :photos, :neighborhood, :string
    add_column :photos, :administrative_area, :string
  end
end
