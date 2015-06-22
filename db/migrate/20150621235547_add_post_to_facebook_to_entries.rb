class AddPostToFacebookToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :post_to_facebook, :boolean
  end
end
