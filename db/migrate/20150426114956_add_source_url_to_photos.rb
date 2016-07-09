class AddSourceUrlToPhotos < ActiveRecord::Migration[4.2]
  def change
    add_column :photos, :source_url, :string
  end
end
