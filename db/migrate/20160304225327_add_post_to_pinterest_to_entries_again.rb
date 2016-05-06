class AddPostToPinterestToEntriesAgain < ActiveRecord::Migration
  def change
    add_column :entries, :post_to_pinterest, :boolean
  end
end
