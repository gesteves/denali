class RenameShowInMapColumn < ActiveRecord::Migration[6.1]
  def up
    rename_column :entries, :show_in_map, :show_location
    remove_column :entries, :show_territories
  end

  def down
    rename_column :entries, :show_location, :show_in_map
    add_column :entries, :show_territories, :boolean, default: true
  end
end
