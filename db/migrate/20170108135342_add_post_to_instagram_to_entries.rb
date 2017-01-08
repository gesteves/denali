class AddPostToInstagramToEntries < ActiveRecord::Migration[5.0]
  def change
    add_column :entries, :post_to_instagram, :boolean
  end
end
