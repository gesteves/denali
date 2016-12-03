class AddPublishedAtToEntries < ActiveRecord::Migration[4.2]
  def change
    add_column :entries, :published_at, :timestamp
  end
end
