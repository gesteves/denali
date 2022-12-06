class RemoveCwFromPhotos < ActiveRecord::Migration[7.0]
  def up
    remove_column :photos, :content_warning
  end

  def down
    add_column :photos, :content_warning, :string
  end
end
