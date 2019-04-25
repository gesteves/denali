class AddFlickrAlbumToTagCustomization < ActiveRecord::Migration[5.2]
  def change
    add_column :tag_customizations, :flickr_albums, :text
  end
end
