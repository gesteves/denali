class AddAnnotationsToPhotos < ActiveRecord::Migration[5.1]
  def change
    add_column :photos, :color, :boolean, default: false
    add_column :photos, :keywords, :string
    add_column :photos, :dominant_color, :string
  end
end
