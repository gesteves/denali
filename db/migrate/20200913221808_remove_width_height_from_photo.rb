class RemoveWidthHeightFromPhoto < ActiveRecord::Migration[6.0]
  def up
    remove_column :photos, :width
    remove_column :photos, :height
  end

  def down
    add_column :photos, :width, :integer
    add_column :photos, :height, :integer
  end
end
