class AddYoToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :send_yo, :boolean
  end
end
