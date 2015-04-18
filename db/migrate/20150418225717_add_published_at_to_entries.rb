class AddPublishedAtToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :published_at, :timestamp
  end
end
