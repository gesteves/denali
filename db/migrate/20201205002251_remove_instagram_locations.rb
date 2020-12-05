class RemoveInstagramLocations < ActiveRecord::Migration[6.0]
  def up
    remove_column :tag_customizations, :instagram_location_id
    remove_column :tag_customizations, :instagram_location_name
  end

  def down
    add_column :tag_customizations, :instagram_location_id, :string
    add_column :tag_customizations, :instagram_location_name, :string
  end
end
