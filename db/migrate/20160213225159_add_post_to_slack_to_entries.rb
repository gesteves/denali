class AddPostToSlackToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :post_to_slack, :boolean
  end
end
