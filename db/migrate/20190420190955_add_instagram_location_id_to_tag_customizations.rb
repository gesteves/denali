class AddInstagramLocationIdToTagCustomizations < ActiveRecord::Migration[5.2]
  def change
    add_column :tag_customizations, :instagram_location_id, :string
  end
end
