class AddPostToPinterestToEntriesAgain < ActiveRecord::Migration[4.2]
  def change
    add_column :entries, :post_to_pinterest, :boolean
  end
end
