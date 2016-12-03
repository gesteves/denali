class AddTumblrIdToEntries < ActiveRecord::Migration[4.2]
  def change
    add_column :entries, :tumblr_id, :string
    add_index :entries, :tumblr_id
  end
end
