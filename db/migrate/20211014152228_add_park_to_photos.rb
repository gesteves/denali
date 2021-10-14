class AddParkToPhotos < ActiveRecord::Migration[6.1]
  def change
    add_column :photos, :park, :string
  end
end
