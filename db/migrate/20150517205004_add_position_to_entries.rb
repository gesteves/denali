class AddPositionToEntries < ActiveRecord::Migration[4.2]
  def change
    add_column :entries, :position, :integer
  end
end
