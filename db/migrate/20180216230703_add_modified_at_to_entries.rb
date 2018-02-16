class AddModifiedAtToEntries < ActiveRecord::Migration[5.1]
  def change
    add_column :entries, :modified_at, :timestamp
  end
end
