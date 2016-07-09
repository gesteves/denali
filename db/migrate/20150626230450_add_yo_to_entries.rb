class AddYoToEntries < ActiveRecord::Migration[4.2]
  def change
    add_column :entries, :send_yo, :boolean
  end
end
