class RemoveNameFromCrops < ActiveRecord::Migration[6.1]
  def up
    remove_column :crops, :name
  end

  def down
    add_column :crops, :name, :string
  end
end
