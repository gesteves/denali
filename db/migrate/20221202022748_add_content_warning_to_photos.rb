class AddContentWarningToPhotos < ActiveRecord::Migration[7.0]
  def change
    add_column :photos, :content_warning, :string
  end
end
