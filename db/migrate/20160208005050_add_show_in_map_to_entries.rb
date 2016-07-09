class AddShowInMapToEntries < ActiveRecord::Migration[4.2]
  def change
    add_column :entries, :show_in_map, :boolean, default: true
  end
end
