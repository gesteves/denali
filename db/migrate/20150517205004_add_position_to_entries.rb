class AddPositionToEntries < ActiveRecord::Migration
  def change
    add_column :entries, :position, :integer
  end
end
