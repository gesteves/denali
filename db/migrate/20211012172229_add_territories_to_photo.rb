class AddTerritoriesToPhoto < ActiveRecord::Migration[6.1]
  def change
    add_column :photos, :territories, :text
    add_column :entries, :show_territories, :boolean, default: true
  end
end
