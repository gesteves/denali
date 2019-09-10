class AddPostToFlickrGroupsToEntries < ActiveRecord::Migration[5.2]
  def change
    add_column :entries, :post_to_flickr_groups, :boolean, default: true
  end
end
