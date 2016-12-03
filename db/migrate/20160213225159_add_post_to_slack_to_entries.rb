class AddPostToSlackToEntries < ActiveRecord::Migration[4.2]
  def change
    add_column :entries, :post_to_slack, :boolean
  end
end
