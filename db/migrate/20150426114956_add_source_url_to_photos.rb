class AddSourceUrlToPhotos < ActiveRecord::Migration
  def change
    add_column :photos, :source_url, :string
  end
end
