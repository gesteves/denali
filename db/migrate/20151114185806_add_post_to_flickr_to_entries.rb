class AddPostToFlickrToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :post_to_flickr, :boolean
  end
end
