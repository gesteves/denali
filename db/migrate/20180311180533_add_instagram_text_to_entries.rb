class AddInstagramTextToEntries < ActiveRecord::Migration[5.1]
  def change
    add_column :entries, :instagram_text, :text
  end
end
