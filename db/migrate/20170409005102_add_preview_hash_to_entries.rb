class AddPreviewHashToEntries < ActiveRecord::Migration[5.0]
  def change
    add_column :entries, :preview_hash, :string
    add_index :entries, :preview_hash
  end
end
