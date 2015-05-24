class AddTumblrIdToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :tumblr_id, :string
    add_index :entries, :tumblr_id
  end
end
