class AddShowInMapToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :show_in_map, :boolean, default: true
  end
end
