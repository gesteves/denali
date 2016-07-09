class AddPostToFlickrToEntries < ActiveRecord::Migration[4.2]
  def change
    add_column :entries, :post_to_flickr, :boolean
  end
end
