class ReAddTumblrIdToEntries < ActiveRecord::Migration[5.2]
  def change
    add_column :entries, :tumblr_id, :string
    add_index :entries, :tumblr_id
  end
end
